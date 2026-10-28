// Wake word: Pilot hears "Pilot" with Apple's offline speech recognizer and at once starts Wispr Flow's hands-free
// mode through Wispr's own link, then stops it when you pause, so Wispr types the command into Pilot's paste
// interceptor. Wispr's mic needs ~0.36 s to open after any trigger (its own fn key too), so in a command said in one
// breath ("Pilot scroll right across space") the words before that come from Apple's transcript, joined to Wispr's
// text (Brain.joinWake). Apple's recognizer is taught Pilot's own sentences (a custom language model, on this Mac).
// "Pilot, dictate" starts Wispr for free text and stops it when you go quiet. Off unless you switch it on (Pilot
// menu, or "start listening"). Main thread only, except the audio tap.
import AppKit
import AVFoundation
import Carbon
import Speech

final class WakeWord {
    static let shared = WakeWord()
    /// "Pilot" was heard; the command follows.
    var onWake: () -> Void = {}
    /// You paused: the words Apple's recognizer heard after "Pilot", whether Wispr recorded the command, and whether you
    /// were still talking once Wispr's mic was on (only then can its text follow as a paste).
    var onCommand: (_ said: [String], _ wispr: Bool, _ wisprHeard: Bool) -> Void = { _, _, _ in }
    /// Is this text already a whole command? A command that is ends after a shorter pause.
    var isCommand: (String) -> Bool = { _ in false }
    var isOn: Bool { UserDefaults.standard.bool(forKey: "wakeWord") }

    // Seconds of quiet (no new words from Apple's recognizer, which reports a word ~0.3 s after you say it) that end a
    // whole command, anything else ("open …"), and a dictation; how long to wait for the first word. Tune here: a
    // shorter pause runs sooner but cuts off anyone who stops mid-command.
    private let quietAfterCommand = 0.4, quietAfterPartial = 1.0, quietAfterDictation = 2.5, waitForFirstWord = 6.0
    // ...and a whole command ends early only once the mic has been quiet longer than the recognizer lags. Without it,
    // "Pilot, hide numbers" stalled at "hide" for 0.4 s while "numbers" was still being said, and Cmd+H hid Chrome.
    private let silenceAfterCommand = 0.6
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
    private var generation = 0, raw: [String] = [], words: [String] = []   // words: raw, lowercased letters
    private var wakeAt: Int?, wordsAtStart = 0, carried: [String] = []   // carried: a command's words from a recognizer that restarted
    private var taskStarted = Date(), lastChange = Date(), sessionStarted = Date(), lastRestart = Date.distantPast
    private var wispr = false, wisprStarted = Date()
    private(set) var wisprStopped = Date.distantPast
    private var timer: Timer?
    private var languageModel: Any?, trained: [String] = []   // an SFSpeechLanguageModel.Configuration (macOS 14+)

    private init() {
        NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main) { [weak self] _ in
            guard let self, isOn || mode != .listening else { return }   // the microphone changed (AirPods connected)
            stopEngine()
            prepare { self.newTask() }
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
    func dictate() { prepare { [self] in if task == nil { newTask() }; begin(.dictation) } }   // listening off: no transcript to hear the pause

    /// Teaches Apple's recognizer the sentences Pilot listens for ("Pilot open chrome", …): a custom language model,
    /// built on this Mac in ~2 s and used from the next transcript on. On 70 of your own recordings from Wispr's history,
    /// it got the words after "Pilot" exactly right in 52 (45 without) and heard "Pilot" in all of them; 18 of 18
    /// synthetic Indian English voices (16 without). Rebuilt only when the phrases change.
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
        if mode == .command { carried = command }   // replaced mid-command: keep what was said, and every word from here on counts
        raw = []; words = []; wordsAtStart = 0; wakeAt = nil; taskStarted = Date()
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

    private func heard(_ segments: [String]) {
        let split = segments.flatMap { $0.split(separator: " ").map(String.init) }   // a final result can hold "Pilot scroll" in one segment
        guard split != raw else { return }
        raw = split
        words = split.map { $0.lowercased().filter(\.isLetter) }
        lastChange = Date()
        guard mode == .listening, let at = words.firstIndex(where: Self.names.contains) else { return }
        // Holding Wispr's fn key: already dictating. The key itself (63), not the fn flag, which a shortcut any app sends
        // can leave on until you next touch the keyboard.
        if CGEventSource.keyState(.hidSystemState, key: 63) {
            Log.debug("Wake word: heard \"\(raw[at])\" with fn held (Wispr's key), so it's Wispr's")
            newTask()
            return
        }
        begin(.command, after: at)   // starts Wispr first: every millisecond here is speech it misses
        Log.debug("Wake word: heard \"\(raw[at])\"" + (wispr ? ", starting Wispr" : "; secure input is on, so Pilot can't catch Wispr's paste and runs its own words"))
        onWake()
    }

    /// The words after "Pilot" so far. Partial results revise words, even the wake word ("Pilot" → "Hi let's"), so it's
    /// looked for again near where it was.
    private var command: [String] {
        let near = wakeAt.flatMap { at in words.indices.filter { Self.names.contains(words[$0]) }.min { abs($0 - at) < abs($1 - at) } }
        return carried + raw.dropFirst(near.map { $0 + 1 } ?? wordsAtStart)
    }

    /// `after`: where "Pilot" is in the transcript; the command is the words after it (it may already have some).
    private func begin(_ m: Mode, after at: Int? = nil) {
        mode = m
        wakeAt = at
        wordsAtStart = (at ?? words.count - 1) + 1
        carried = []
        sessionStarted = Date()
        lastChange = Date()
        wispr = m == .dictation || !IsSecureEventInputEnabled()   // secure input (Terminal's Secure Keyboard Entry) hides Wispr's paste from Pilot
        guard wispr else { return }
        let wait = max(0, wisprStopped.timeIntervalSinceNow + 0.5)   // Wispr ignores a start while it finishes the last session
        wisprStarted = Date() + wait
        if wait > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.openWispr("start-hands-free") } } else { openWispr("start-hands-free") }
    }

    private func tick() {
        lock.lock(); let audio = Date().timeIntervalSince(lastBuffer) < 2; lock.unlock()
        guard engine.isRunning, audio else {   // the mic stopped by itself (sleep, a device gone): start it again
            if isOn || mode != .listening, Date().timeIntervalSince(lastRestart) > 3 {
                lastRestart = Date()
                Log.debug("Wake word: the microphone stopped, restarting it")
                stopEngine()
                prepare { self.newTask() }
            }
            return
        }
        let quiet = Date().timeIntervalSince(lastChange), elapsed = Date().timeIntervalSince(sessionStarted)
        switch mode {
        case .listening:
            if Date().timeIntervalSince(taskStarted) > 60, quiet > 1 { newTask() }   // never mid-word
        case .dictation:
            let spoke = words.count > wordsAtStart
            if (spoke ? quiet > quietAfterDictation : elapsed > waitForFirstWord) || elapsed > 120 { finish(spoke: spoke) }
        case .command:
            let said = command, spoke = !said.isEmpty
            lock.lock(); let silent = Date().timeIntervalSince(lastLoud); lock.unlock()
            let early = quiet > quietAfterCommand && silent > silenceAfterCommand && isCommand(said.joined(separator: " "))
            let done = spoke ? quiet > quietAfterPartial || early : elapsed > waitForFirstWord
            if done || elapsed > 10 { finish(spoke: spoke) }
        }
    }

    private func finish(spoke: Bool) {
        let took = String(format: "%.1f s", Date().timeIntervalSince(sessionStarted))
        if wispr { openWispr("stop-hands-free"); wisprStopped = Date() }
        if mode == .command {
            let said = command
            lock.lock(); let loud = lastLoud; lock.unlock()
            let wisprHeard = wispr && loud > wisprStarted + wisprMicDelay + 0.15   // still talking once Wispr's mic was on
            Log.debug("Wake word: \(spoke ? "heard \"\(said.joined(separator: " "))\"" : "nothing said") after \(took)"
                      + (wispr ? (wisprHeard ? "; Wispr heard you too" : "; you'd finished before Wispr's mic was on") : ""))
            mode = .listening
            onCommand(said, wispr, wisprHeard)
        } else {
            mode = .listening
            Log.debug("Wake word: stopped Wispr after \(took) (\(spoke ? "you spoke" : "nothing said"))")
        }
        if isOn { newTask() } else { stopEngine() }   // a dictation can run with listening off
    }

    private func openWispr(_ route: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // your app stays in front, so Wispr's text lands there
        NSWorkspace.shared.open(URL(string: "wispr-flow://" + route)!, configuration: config)
    }
}
