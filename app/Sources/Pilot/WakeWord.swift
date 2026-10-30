// Wake word: Pilot hears its name, "Pilot", with Apple's offline speech recognizer and at once starts Wispr Flow's
// hands-free mode through Wispr's own link. The name is the only word Pilot ever takes from Apple's recognizer: the
// moment it's heard the transcript is cancelled, so nothing after it is transcribed, run, typed or logged. Wispr writes
// every command. When the microphone goes quiet (its loudness, not words) Pilot stops Wispr, and Wispr's paste is the
// command. Wispr's mic needs ~0.37 s to open, so the HUD says "🎙 Listening…" only then. "Pilot, dictate" starts
// Wispr for free text and stops it when you go quiet. Off unless you switch it on (Pilot menu, or "start listening").
// Main thread only, except the audio tap.
import AppKit
import AVFoundation
import Carbon
import Speech

final class WakeWord {
    static let shared = WakeWord()
    /// "Pilot" was heard: Wispr is starting.
    var onWake: () -> Void = {}
    /// Wispr's mic is on: say the command now.
    var onListening: () -> Void = {}
    /// You went quiet and Pilot stopped Wispr: whether you spoke while its mic was on (only then can its text follow).
    var onCommand: (_ spoke: Bool) -> Void = { _ in }
    var isOn: Bool { UserDefaults.standard.bool(forKey: "wakeWord") }

    // Seconds of quiet (the mic's loudness) that end a command and a dictation, how long to wait for you to start once
    // Wispr's mic is on, and the longest a command may run. Tune here: a shorter pause runs sooner but cuts off anyone
    // who stops mid-command (a beat at a comma is ~0.5 s).
    private let quietAfterCommand = 1.0, quietAfterDictation = 2.0, waitForFirstWord = 6.0, longestCommand = 15.0
    // Measured on this Mac (29 Oct): Wispr's mic is on 0.35–0.38 s after its link or its fn key.
    private let wisprMicDelay = 0.37
    /// How Apple's recognizer writes "Pilot". "Violet" came up twice on 70 of your recordings; "Pilots" / "Pilot's" too.
    private static let names: Set<String> = ["pilot", "pilots", "pilate", "pilates", "violet"]

    private enum Mode { case listening, command, dictation }
    private var mode = Mode.listening
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer? = {
        let r = SFSpeechRecognizer()   // your language, if it works offline
        return r?.supportsOnDeviceRecognition == true ? r : SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private let lock = NSLock()   // guards the four below: the audio thread writes them
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var lastBuffer = Date(), lastLoud = Date.distantPast, noiseFloor: Float = -50
    private var task: SFSpeechRecognitionTask?
    private var generation = 0, words: [String] = []   // the transcript while listening for the name, lowercased letters
    private var taskStarted = Date(), lastChange = Date(), sessionStarted = Date(), lastRestart = Date.distantPast
    private var wisprStarted = Date()
    private(set) var wisprStopped = Date.distantPast
    private var timer: Timer?
    private var languageModel: Any?, trained: [String] = []   // an SFSpeechLanguageModel.Configuration (macOS 14+)

    private init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, isOn || mode != .listening else { return }   // the microphone changed (AirPods connected)
            stopEngine()
            prepare { if self.mode == .listening { self.newTask() } }
        }
    }

    /// Listening for "Pilot" on or off, remembered across restarts.
    func setOn(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: "wakeWord")
        if on {
            prepare { [self] in
                newTask()
                Log.debug("Wake word: listening (\(recognizer?.locale.identifier ?? "?"), offline)")
            }
        } else if mode == .listening {
            stopEngine()
            Log.debug("Wake word: off")
        }
    }

    /// "Pilot, dictate": Wispr types whatever you say next, until you pause. Works with listening off too.
    func dictate() { prepare { [self] in begin(.dictation) } }

    /// Teaches Apple's recognizer the sentences the name comes in ("Pilot open chrome", …), so it hears "Pilot" reliably:
    /// a custom language model, built on this Mac in ~2 s and used from the next transcript on. It heard "Pilot" in all
    /// 70 of your recordings from Wispr's history. Only the name is ever used. Rebuilt only when the phrases change.
    func train(_ phrases: [String]) {
        guard #available(macOS 14, *), let locale = recognizer?.locale else { return }
        let sentences = ["Pilot"] + phrases.map { "Pilot " + $0 }
        guard sentences != trained else { return }
        trained = sentences
        let dir = Log.dir.appendingPathComponent("speech")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let asset = dir.appendingPathComponent("pilot.bin")
        let config = SFSpeechLanguageModel.Configuration(languageModel: dir.appendingPathComponent("pilot.lm"), vocabulary: dir.appendingPathComponent("pilot.vocab"))
        let start = Date()
        Task {
            let data = SFCustomLanguageModelData(locale: locale, identifier: "dev.jsurya.pilot", version: "1")
            data.insert(phraseCount: .init(phrase: "Pilot", count: 50))
            for s in sentences.dropFirst() { data.insert(phraseCount: .init(phrase: s, count: 10)) }
            do {
                try await data.export(to: asset)
                if #available(macOS 26, *) { try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: asset, configuration: config) }
                else { try await SFSpeechLanguageModel.prepareCustomLanguageModel(for: asset, clientIdentifier: "dev.jsurya.pilot", configuration: config) }
                let count = sentences.count
                DispatchQueue.main.async {
                    let w = WakeWord.shared
                    w.languageModel = config
                    Log.debug(String(format: "Wake word: taught the recognizer %d sentences in %.1f s", count, Date().timeIntervalSince(start)))
                    if w.mode == .listening, w.task != nil { w.newTask() }   // use it now
                }
            } catch {
                Log.debug("Wake word: couldn't build the language model, using the plain one: \(error.localizedDescription)")
            }
        }
    }

    /// Permissions, then the microphone, then `then`.
    private func prepare(_ then: @escaping () -> Void) {
        SFSpeechRecognizer.requestAuthorization { speech in
            AVCaptureDevice.requestAccess(for: .audio) { mic in
                DispatchQueue.main.async { [self] in
                    guard speech == .authorized, mic else {
                        UserDefaults.standard.set(false, forKey: "wakeWord")
                        HUD.show("⚠︎ Allow Pilot under System Settings → Privacy & Security → Microphone and Speech Recognition", seconds: 5)
                        return
                    }
                    guard recognizer?.supportsOnDeviceRecognition == true else { HUD.show("⚠︎ Offline speech recognition isn't available"); return }
                    if !engine.isRunning {
                        do { try startEngine() } catch { HUD.show("⚠︎ Couldn't open the microphone: \(error.localizedDescription)"); return }
                    }
                    then()
                }
            }
        }
    }

    private func startEngine() throws {
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { [weak self] buffer, _ in
            guard let self else { return }
            let db = Self.level(buffer), now = Date()
            lock.lock()
            request?.append(buffer)
            lastBuffer = now
            noiseFloor = db < noiseFloor ? db : noiseFloor + (db - noiseFloor) * 0.002   // drops at once, rises slowly
            if db > max(noiseFloor + 15, -60) { lastLoud = now }   // speech, not the room
            lock.unlock()
        }
        engine.prepare()
        try engine.start()
        lock.lock(); lastBuffer = Date(); lock.unlock()
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.tick() } }
    }

    /// Loudness of a buffer, in dB below full scale.
    private static func level(_ b: AVAudioPCMBuffer) -> Float {
        guard let d = b.floatChannelData?[0], b.frameLength > 0 else { return -100 }
        var sum: Float = 0
        for i in 0..<Int(b.frameLength) { sum += d[i] * d[i] }
        return 10 * log10(sum / Float(b.frameLength) + 1e-10)
    }

    private func stopEngine() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        task?.cancel()
        task = nil
        lock.lock(); request?.endAudio(); request = nil; lock.unlock()
    }

    /// A fresh transcript, so one "Pilot" can't fire twice and a task never grows all day.
    private func newTask() {
        guard let recognizer else { return }
        task?.cancel()
        let r = SFSpeechAudioBufferRecognitionRequest()
        r.requiresOnDeviceRecognition = true   // never leaves the Mac
        r.shouldReportPartialResults = true
        r.contextualStrings = ["Pilot"]
        if #available(macOS 14, *), let lm = languageModel as? SFSpeechLanguageModel.Configuration { r.customizedLanguageModel = lm }
        lock.lock(); request?.endAudio(); request = r; lock.unlock()
        generation += 1
        let gen = generation
        words = []; taskStarted = Date()
        task = recognizer.recognitionTask(with: r) { [weak self] result, error in
            guard let self, gen == generation else { return }   // a task already replaced
            if let result { heard(result.bestTranscription.segments.map(\.substring)) }
            if (error != nil || result?.isFinal == true), engine.isRunning {   // e.g. a long silence ended it, even mid-command
                let failing = Date().timeIntervalSince(taskStarted) < 1   // at once: don't spin; otherwise no deaf gap
                if failing, let error { Log.debug("Wake word: the recognizer failed (\(error.localizedDescription)), retrying") }
                DispatchQueue.main.asyncAfter(deadline: .now() + (failing ? 0.5 : 0)) { [weak self] in if self?.generation == gen { self?.newTask() } }
            }
        }
    }

    /// Only ever looks for the name. Nothing else in the transcript is kept past this function.
    private func heard(_ segments: [String]) {
        guard mode == .listening else { return }
        let split = segments.flatMap { $0.split(separator: " ") }.map { $0.lowercased().filter(\.isLetter) }   // a final result can hold "Pilot scroll" in one segment
        guard split != words else { return }
        words = split
        lastChange = Date()
        // the name on its own: "pilot" in "No Hands Pilot" (the project's name) isn't you calling it
        guard words.indices.contains(where: { Self.names.contains(words[$0]) && ($0 == 0 || words[$0 - 1] != "hands") }) else { return }
        // Holding Wispr's fn key: already dictating. The key itself (63), not the fn flag, which a shortcut any app sends
        // can leave on until you next touch the keyboard.
        if CGEventSource.keyState(.hidSystemState, key: 63) {
            Log.debug("Wake word: heard the name with fn held (Wispr's key), so it's Wispr's")
            newTask()
            return
        }
        begin(.command)   // starts Wispr first: every millisecond here is speech it misses
        Log.debug("Wake word: heard the name, starting Wispr" + (IsSecureEventInputEnabled() ? " (secure input is on: its paste is read from the clipboard)" : ""))
        onWake()
    }

    /// Stops transcribing (the name was the last word Apple's recognizer gets) and starts Wispr.
    private func begin(_ m: Mode) {
        mode = m
        generation += 1   // any late result of the old transcript is ignored
        task?.cancel()
        task = nil
        lock.lock(); request?.endAudio(); request = nil; lock.unlock()
        words = []
        sessionStarted = Date()
        let wait = max(0, wisprStopped.timeIntervalSinceNow + 0.5)   // Wispr ignores a start while it finishes the last session
        wisprStarted = Date() + wait
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.openWispr("start-hands-free") }
        DispatchQueue.main.asyncAfter(deadline: .now() + wait + wisprMicDelay) { [self] in if mode == m { onListening() } }
    }

    private func tick() {
        lock.lock(); let audio = Date().timeIntervalSince(lastBuffer) < 2, loud = lastLoud; lock.unlock()
        guard engine.isRunning, audio else {   // the mic stopped by itself (sleep, a device gone): start it again
            if isOn || mode != .listening, Date().timeIntervalSince(lastRestart) > 3 {
                lastRestart = Date()
                Log.debug("Wake word: the microphone stopped, restarting it")
                stopEngine()
                prepare { if self.mode == .listening { self.newTask() } }
            }
            return
        }
        if mode == .listening {
            if Date().timeIntervalSince(taskStarted) > 60, Date().timeIntervalSince(lastChange) > 1 { newTask() }   // never mid-word
            return
        }
        let spoke = loud > wisprStarted + wisprMicDelay   // only what Wispr's mic could hear counts
        let quiet = Date().timeIntervalSince(loud), elapsed = Date().timeIntervalSince(sessionStarted)
        let pause = mode == .command ? quietAfterCommand : quietAfterDictation
        if spoke ? quiet > pause : elapsed > waitForFirstWord + wisprMicDelay { finish(spoke: spoke) }
        else if elapsed > (mode == .command ? longestCommand : 120) { finish(spoke: spoke) }
    }

    private func finish(spoke: Bool) {
        let took = String(format: "%.1f s", Date().timeIntervalSince(sessionStarted))
        openWispr("stop-hands-free")
        wisprStopped = Date()
        let was = mode
        mode = .listening
        Log.debug("Wake word: stopped Wispr after \(took) (\(spoke ? "you spoke" : "nothing said"))")
        if was == .command { onCommand(spoke) }
        if isOn { newTask() } else { stopEngine() }   // a dictation can run with listening off
    }

    private func openWispr(_ route: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // your app stays in front, so Wispr's text lands there
        NSWorkspace.shared.open(URL(string: "wispr-flow://" + route)!, configuration: config)
    }
}
