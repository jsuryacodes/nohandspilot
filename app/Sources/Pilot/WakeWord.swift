// Wake word: Pilot hears "Pilot" with Apple's offline speech recognizer, then starts Wispr Flow's hands-free mode
// through Wispr's own link and stops it when you go quiet. Wispr still hears and types every command; this only
// replaces holding its key. Off unless you switch it on (Pilot menu, or "start listening"). Main thread only.
import AppKit
import AVFoundation
import Carbon
import Speech

final class WakeWord {
    static let shared = WakeWord()
    /// "Pilot" was heard and Wispr is listening: its next text is a command, even without the word.
    var onWake: () -> Void = {}
    /// Wispr was stopped after a command; whatever it heard is on the way.
    var onCommandDone: () -> Void = {}
    var isOn: Bool { UserDefaults.standard.bool(forKey: "wakeWord") }

    // Seconds of quiet that end a command or a dictation, and how long to wait for the first word. Tune here.
    private let quietAfterCommand = 0.8, quietAfterDictation = 2.5, waitForFirstWord = 6.0

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
    private var generation = 0, words: [String] = [], checked = 0, wordsAtStart = 0
    private var taskStarted = Date(), lastChange = Date(), sessionStarted = Date()
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
        if timer == nil { timer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in self?.tick() } }
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
        words = []; checked = 0; taskStarted = Date()
        if mode != .listening { wordsAtStart = 0 }   // replaced mid-command: every word from here on is the command
        task = recognizer.recognitionTask(with: r) { [weak self] result, error in
            guard let self, gen == generation else { return }   // a task already replaced
            if let result { heard(result.bestTranscription.segments.map { $0.substring.lowercased().filter(\.isLetter) }) }
            if (error != nil || result?.isFinal == true), engine.isRunning {   // e.g. a long silence ended it, even mid-command
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in if self?.generation == gen { self?.newTask() } }
            }
        }
    }

    private func heard(_ now: [String]) {
        guard now != words else { return }
        words = now
        lastChange = Date()
        guard mode == .listening else { return }
        // partial results revise the last word or two ("pile" → "pilot"), so look at those again
        let wake = words.dropFirst(max(0, checked - 2)).contains { $0 == "pilot" || $0 == "pilate" }
        checked = words.count
        guard wake else { return }
        if CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn) { newTask(); return }   // holding Wispr's key: already dictating
        if IsSecureEventInputEnabled() {   // Terminal's Secure Keyboard Entry or a password field hides Wispr's paste from Pilot, so it would be typed
            Log.debug("Wake word: heard \"Pilot\", but secure input is on; not starting Wispr")
            HUD.show("⚠︎ Secure input is on, so Wispr would type the command. In Terminal: Terminal menu → Secure Keyboard Entry", seconds: 4)
            newTask(); return
        }
        Log.debug("Wake word: heard \"Pilot\", starting Wispr")
        begin(.command)
        onWake()
    }

    private func begin(_ m: Mode) {
        mode = m
        wordsAtStart = words.count
        sessionStarted = Date()
        lastChange = Date()
        openWispr("start-hands-free")
    }

    private func tick() {
        guard engine.isRunning else { return }
        let quiet = Date().timeIntervalSince(lastChange), elapsed = Date().timeIntervalSince(sessionStarted)
        switch mode {
        case .listening:
            if Date().timeIntervalSince(taskStarted) > 60 { newTask() }
        case .command, .dictation:
            let spoke = words.count > wordsAtStart
            let done = spoke ? quiet > (mode == .command ? quietAfterCommand : quietAfterDictation) : elapsed > waitForFirstWord
            if done || elapsed > (mode == .command ? 20 : 120) { finish(spoke: spoke) }
        }
    }

    private func finish(spoke: Bool) {
        let command = mode == .command
        mode = .listening
        openWispr("stop-hands-free")
        Log.debug(String(format: "Wake word: stopped Wispr after %.1f s (%@)", Date().timeIntervalSince(sessionStarted), spoke ? "you spoke" : "nothing said"))
        if command { onCommandDone() }
        if isOn { newTask() } else { stopEngine() }   // a dictation can run with listening off
    }

    private func openWispr(_ route: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = false   // your app stays in front, so Wispr's text lands there
        NSWorkspace.shared.open(URL(string: "wispr-flow://" + route)!, configuration: config)
    }
}
