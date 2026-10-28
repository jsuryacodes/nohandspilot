// Wake word: Pilot hears "Pilot" with Apple's offline speech recognizer and at once starts Wispr Flow's hands-free
// mode through Wispr's own link, then stops it when you pause, so Wispr types the command into Pilot's paste
// interceptor. Wispr's mic needs ~0.36 s to open after any trigger (its own fn key too), so in a command said in one
// breath ("Pilot scroll right across space") the words before that come from Apple's transcript, joined to Wispr's
// text. "Pilot, dictate" starts Wispr for free text and stops it when you go quiet. Off unless you switch it on
// (Pilot menu, or "start listening"). Main thread only.
import AppKit
import AVFoundation
import Carbon
import Speech

final class WakeWord {
    static let shared = WakeWord()
    /// "Pilot" was heard; the command follows.
    var onWake: () -> Void = {}
    /// You paused: the words Apple's recognizer heard after "Pilot", how many of them came before Wispr's mic was on,
    /// and whether Wispr recorded the command (its text then follows as a paste).
    var onCommand: (_ said: [String], _ missed: Int, _ wispr: Bool) -> Void = { _, _, _ in }
    var isOn: Bool { UserDefaults.standard.bool(forKey: "wakeWord") }

    // Seconds of quiet that end a command or a dictation, and how long to wait for the first word. Tune here:
    // a shorter command pause runs sooner but cuts off anyone who stops mid-command.
    private let quietAfterCommand = 0.5, quietAfterDictation = 2.5, waitForFirstWord = 6.0
    // Measured on this Mac (29 Oct): Wispr's mic is on 0.35–0.38 s after its link or its fn key, and Apple's
    // recognizer reports a word ~0.3 s after you finish it.
    private let wisprMicDelay = 0.4, recognizerLag = 0.3

    private enum Mode { case listening, command, dictation }
    private var mode = Mode.listening
    private let engine = AVAudioEngine()
    private let recognizer: SFSpeechRecognizer? = {
        let r = SFSpeechRecognizer()   // your language, if it works offline
        return r?.supportsOnDeviceRecognition == true ? r : SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    }()
    private let lock = NSLock()
    private var request: SFSpeechAudioBufferRecognitionRequest?   // the audio thread appends to it, under `lock`
    private var task: SFSpeechRecognitionTask?
    private var generation = 0, raw: [String] = [], words: [String] = [], checked = 0, wordsAtStart = 0   // words: raw, lowercased letters
    private var taskStarted = Date(), lastChange = Date(), sessionStarted = Date()
    private var wispr = false, wisprStarted = Date()
    private(set) var wisprStopped = Date.distantPast
    private var wisprFrom: Int?   // index in `raw` of the first word said after Wispr's mic was on
    private var timer: Timer?

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
            lock.lock(); request?.append(buffer); lock.unlock()
        }
        engine.prepare()
        try engine.start()
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() } }
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
        lock.lock(); request?.endAudio(); request = r; lock.unlock()
        generation += 1
        let gen = generation
        raw = []; words = []; checked = 0; taskStarted = Date()
        if mode != .listening {   // replaced mid-command: every word from here on is the command
            wordsAtStart = 0
            if wisprFrom != nil { wisprFrom = 0 }
        }
        task = recognizer.recognitionTask(with: r) { [weak self] result, error in
            guard let self, gen == generation else { return }   // a task already replaced
            if let result { heard(result.bestTranscription.segments.map(\.substring)) }
            if (error != nil || result?.isFinal == true), engine.isRunning {   // e.g. a long silence ended it, even mid-command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in if self?.generation == gen { self?.newTask() } }
            }
        }
    }

    private func heard(_ segments: [String]) {
        guard segments != raw else { return }
        raw = segments
        words = segments.map { $0.lowercased().filter(\.isLetter) }
        lastChange = Date()
        guard mode == .listening else { return }
        // partial results revise the last word or two ("pile" → "pilot"), so look at those again
        let wakeAt = words.indices.dropFirst(max(0, checked - 2)).first { words[$0] == "pilot" || words[$0] == "pilate" }
        checked = words.count
        guard let wakeAt else { return }
        if CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn) { newTask(); return }   // holding Wispr's key: already dictating
        begin(.command, after: wakeAt)   // starts Wispr first: every millisecond here is speech it misses
        Log.debug("Wake word: heard \"Pilot\"" + (wispr ? ", starting Wispr" : "; secure input is on, so Pilot can't catch Wispr's paste and runs its own words"))
        onWake()
    }

    /// `after`: where "Pilot" is in the transcript; the command is the words after it (it may already have some).
    private func begin(_ m: Mode, after wakeAt: Int? = nil) {
        mode = m
        wordsAtStart = (wakeAt ?? words.count - 1) + 1
        wisprFrom = nil
        sessionStarted = Date()
        lastChange = Date()
        wispr = m == .dictation || !IsSecureEventInputEnabled()   // secure input (Terminal's Secure Keyboard Entry) hides Wispr's paste from Pilot
        guard wispr else { return }
        let wait = max(0, wisprStopped.timeIntervalSinceNow + 0.5)   // Wispr ignores a start while it finishes the last session
        wisprStarted = Date() + wait
        if wait > 0 { DispatchQueue.main.asyncAfter(deadline: .now() + wait) { self.openWispr("start-hands-free") } } else { openWispr("start-hands-free") }
    }

    private func tick() {
        guard engine.isRunning else { return }
        let quiet = Date().timeIntervalSince(lastChange), elapsed = Date().timeIntervalSince(sessionStarted)
        switch mode {
        case .listening:
            if Date().timeIntervalSince(taskStarted) > 60 { newTask() }
        case .command, .dictation:
            if mode == .command, wispr, wisprFrom == nil, Date().timeIntervalSince(wisprStarted) > wisprMicDelay + recognizerLag {
                wisprFrom = words.count   // the words Apple has by now were said before Wispr's mic was on
            }
            let spoke = words.count > wordsAtStart
            let done = spoke ? quiet > (mode == .command ? quietAfterCommand : quietAfterDictation) : elapsed > waitForFirstWord
            if done || elapsed > (mode == .command ? 20 : 120) { finish(spoke: spoke) }
        }
    }

    private func finish(spoke: Bool) {
        let took = String(format: "%.1f s", Date().timeIntervalSince(sessionStarted))
        if wispr { openWispr("stop-hands-free"); wisprStopped = Date() }
        if mode == .command {
            let said = Array(raw.dropFirst(wordsAtStart))   // without the word, which may have come out as "Pilate"
            let missed = min(said.count, max(0, (wisprFrom ?? raw.count) - wordsAtStart))
            Log.debug("Wake word: \(spoke ? "heard \"\(said.joined(separator: " "))\"" : "nothing said") after \(took)"
                      + (wispr ? "; Wispr's mic missed \(missed) of the words" : ""))
            mode = .listening
            onCommand(said, missed, wispr)
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
