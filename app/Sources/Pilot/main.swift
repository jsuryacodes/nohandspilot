// Pilot: menu-bar app. Wispr is the ears, the Brain decides, Hands act.
import AppKit
import Carbon
import PilotBrain
import ServiceManagement

enum Log {
    static let dir: URL = {
        let d = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Pilot")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }()
    static let usageURL = dir.appendingPathComponent("usage.jsonl")
    static let debugURL = dir.appendingPathComponent("debug.log")
    private static let stamp: ISO8601DateFormatter = { let f = ISO8601DateFormatter(); f.timeZone = .current; return f }()

    static func append(_ line: String, to url: URL) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(data); try? h.close() }
        else { try? data.write(to: url) }
    }

    static func debug(_ s: String) {
        print(s)
        append("\(stamp.string(from: Date())) \(s)", to: debugURL)
    }

    /// Every command Pilot handled. Normal dictation is never logged.
    static func usage(source: String, text: String, matched: [String], ok: Bool, error: String?, matchMs: Double, totalMs: Double) {
        guard source != "cli" else { return }   // terminal tests aren't real usage
        var e: [String: Any] = ["time": stamp.string(from: Date()), "source": source, "text": text, "matched": matched, "ok": ok,
                                "matchMs": Decimal(string: String(format: "%.1f", matchMs))!, "totalMs": Int(totalMs.rounded())]
        if let error { e["error"] = error }
        if let d = try? JSONSerialization.data(withJSONObject: e, options: [.sortedKeys]), let s = String(data: d, encoding: .utf8) { append(s, to: usageURL) }
    }

    static func today() -> (ok: Int, wispr: Int) {
        let day = String(stamp.string(from: Date()).prefix(10))
        var ok = 0, wispr = 0
        for line in ((try? String(contentsOf: usageURL, encoding: .utf8)) ?? "").split(separator: "\n") where line.contains("\"time\":\"\(day)") {
            guard let o = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any], o["ok"] as? Bool == true else { continue }
            ok += 1
            if o["source"] as? String == "wispr" { wispr += 1 }
        }
        return (ok, wispr)
    }
}

final class Pilot {
    private(set) var brain: Brain?
    let commandsURL: URL = {
        if let p = Bundle.main.object(forInfoDictionaryKey: "PilotCommandsPath") as? String, FileManager.default.fileExists(atPath: p) {
            return URL(fileURLWithPath: p)   // the repo's commands/commands.json, so edits apply on the next command
        }
        return Bundle.main.url(forResource: "commands", withExtension: "json") ?? URL(fileURLWithPath: "commands.json")
    }()
    /// Phrases taught by voice, next to commands.json (never inside the signed app bundle).
    lazy var learnedURL: URL = (commandsURL.path.hasPrefix(Bundle.main.bundlePath) ? Log.dir : commandsURL.deletingLastPathComponent())
        .appendingPathComponent("learned.json")
    private(set) var learned: [String: [String]] = [:]
    private var loadedAt: [Date?] = []
    private var lastMiss: String?   // for "teach that"
    /// Wake word: until when Wispr's next paste is the command it's writing, and whether one already came. `wakes` counts them.
    private var wakeUntil = Date.distantPast, wakeTaken = false, wakes = 0
    /// Called with each newly loaded Brain (the app teaches the wake word its sentences).
    var onLoad: (Brain) -> Void = { _ in }
    static let noWispr = "Didn't get that from Wispr. Say it again"
    static let secureInput = "Terminal's Secure Keyboard Entry is on. Pilot can't see Wispr here. Turn it off in Terminal's menu → Secure Keyboard Entry"

    /// Wake word heard: Wispr is writing the command. Its paste is the command, whatever it starts with.
    func wakeStarted() {
        wakes += 1
        wakeUntil = .distantFuture
        wakeTaken = false
    }

    /// Wake word, once you went quiet and Pilot stopped Wispr. Only Wispr's text ever runs: if none comes, nothing does.
    func wakeCommand(spoke: Bool) {
        guard spoke else {
            wakeUntil = Date() + 1.5   // drop any scrap Wispr sends
            HUD.show(Self.noWispr, seconds: 3)
            return
        }
        // Wispr's text comes 0.4 s after the stop (median of 2,598 in its history), within 1.1 s for 95%.
        wakeUntil = Date() + 2.5
        let id = wakes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [self] in
            guard wakes == id, !wakeTaken else { return }
            wakeUntil = Date() + 2   // late text is still never typed
            Log.debug("Wake word: no text from Wispr in 2.5 s, ran nothing")
            HUD.show(IsSecureEventInputEnabled() ? Self.secureInput : Self.noWispr, seconds: 4)
        }
    }

    /// A paste Wispr wrote after the wake word: true if it belongs to one (then it's run once, or dropped).
    private func wakePaste(_ text: String) -> Bool {
        guard Date() < wakeUntil else { return false }
        if wakeTaken { Log.debug("Wake word: a second paste from Wispr, dropped"); return true }
        wakeTaken = true
        wakeUntil = Date() + 1   // a scrap right after is dropped; "Pilot, dictate"'s own text comes later and types
        reloadIfChanged()
        let command = brain?.wakeCommand(text) ?? text
        Log.debug("Wake word: Wispr typed \"\(text)\"")
        handle("Pilot, " + command, source: "wispr", frontApp: appName(NSWorkspace.shared.frontmostApplication))
        return true
    }

    /// Every paste from Wispr. Returns true to swallow it.
    func wisprPaste(_ text: String) -> Bool {
        wakePaste(text) || handle(text, source: "wispr", frontApp: appName(NSWorkspace.shared.frontmostApplication))
    }

    /// Wispr's text already landed (secure input hid its paste): if it's a command, erase exactly it (never Ctrl+U, which
    /// takes what you typed before) and run it.
    func landedPaste(_ text: String) {
        guard reloadIfChanged() == nil, (Date() < wakeUntil && !wakeTaken) || brain?.stripTrigger(text) != nil else { return }
        Hands.queue.async { Hands.backspace(text.count) }
        _ = wisprPaste(text)
    }

    /// Reloads commands.json and learned.json if either changed since last time. Returns an error message if one is broken.
    @discardableResult func reloadIfChanged(force: Bool = false) -> String? {
        let stamps = [commandsURL, learnedURL].map { (try? FileManager.default.attributesOfItem(atPath: $0.path)[.modificationDate]) as? Date }
        guard force || brain == nil || stamps != loadedAt else { return nil }
        var file = "commands.json"
        do {
            if Hands.installed.isEmpty { Hands.scanApps() }
            var config = try JSONDecoder().decode(Config.self, from: Data(contentsOf: commandsURL))
            file = "learned.json"
            learned = try FileManager.default.fileExists(atPath: learnedURL.path)
                ? JSONDecoder().decode([String: [String]].self, from: Data(contentsOf: learnedURL)) : [:]
            config.macros.merge(learned) { builtIn, _ in builtIn }
            brain = Brain(config: config, installedApps: Array(Hands.installed.keys), appAliases: Hands.aliases,
                          slotValues: ["profile": Hands.chromeProfiles(), "folder": Hands.knownFolders()])
            Hands.browser = brain!.config.browser ?? Hands.browser
            brain!.menuItems = { Screen.menus(of: $0) }
            loadedAt = stamps
            onLoad(brain!)
            Log.debug("Loaded \(brain!.config.commands.count) commands and \(learned.count) taught phrases from \(commandsURL.deletingLastPathComponent().path)")
            return nil
        } catch {
            Log.debug("\(file) error: \(error)")
            return "\(file) has an error: \(error.localizedDescription)"
        }
    }

    /// "when I say X, do …" / "teach that: …" / "forget X". Returns the toast.
    private func learn(_ phrase: String?, _ commands: [String], forget: Bool, brain: Brain, frontApp: String?) -> String {
        let said: String
        if forget {
            guard let key = learned.keys.first(where: { brain.normalize($0) == brain.normalize(phrase ?? "") }) else { return "⚠︎ \"\(phrase ?? "")\" isn't a taught phrase" }
            said = key
            learned[key] = nil
        } else {
            guard let p = phrase ?? lastMiss else { return "⚠︎ Nothing to teach yet. Say the command, then \"teach that: …\"" }
            guard !brain.normalize(p).isEmpty, !commands.isEmpty else { return "⚠︎ Say it as \"when I say …, do …\"" }
            switch brain.plan(p, frontmostApp: frontApp, requireTrigger: false, typos: false) {
            case .unmatched: break
            case .run(let steps): return "⚠︎ \"\(p)\" already means " + steps.map(\.say).joined(separator: " → ") + (learned[p.lowercased()] != nil ? ". Say \"forget \(p)\" first" : "")
            default: return "⚠︎ \"\(p)\" can't be taught"
            }
            for c in commands {
                guard case .run = brain.plan(c, frontmostApp: frontApp, requireTrigger: false) else { return "⚠︎ Didn't catch \"\(c)\", so nothing was taught" }
            }
            said = p.lowercased()
            learned[said] = commands
            lastMiss = nil
        }
        do {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try enc.encode(learned).write(to: learnedURL, options: .atomic)
        } catch { return "⚠︎ Couldn't save learned.json: \(error.localizedDescription)" }
        if let err = reloadIfChanged(force: true) { return "⚠︎ \(err)" }
        return forget ? "✓ Forgot \"\(said)\"" : "✓ Learned \"\(said)\" → " + commands.joined(separator: ", ")
    }

    /// Returns true if Pilot acts on the text or a Wispr paste was meant for Pilot (so the paste should be swallowed).
    @discardableResult func handle(_ text: String, source: String, frontApp: String?, waitForFocusFrom pilotApp: Bool = false) -> Bool {
        let start = Date()
        if let err = reloadIfChanged() { HUD.show("⚠︎ \(err)"); return false }
        guard let brain else { return false }
        let plan = brain.plan(text, frontmostApp: frontApp, requireTrigger: source == "wispr")
        let matchMs = Date().timeIntervalSince(start) * 1000
        func taught(_ toast: String, _ id: String) -> Bool {
            HUD.show(toast, seconds: 3)
            Log.debug("Teach: \(toast)")
            Log.usage(source: source, text: text, matched: [id], ok: toast.hasPrefix("✓"), error: toast.hasPrefix("✓") ? nil : toast,
                      matchMs: matchMs, totalMs: Date().timeIntervalSince(start) * 1000)
            return true
        }
        switch plan {
        case .notForPilot:
            return false
        case .unmatched(let segment, let suggestion):
            lastMiss = segment.isEmpty ? nil : segment
            HUD.show("Didn't catch \"\(segment.isEmpty ? text : segment)\"" + (suggestion.map { ". Try \"\($0)\"" } ?? "")
                     + ". Or say \"teach that: …\"", seconds: 3)
            Log.usage(source: source, text: text, matched: [], ok: false, error: "unmatched: \(segment)", matchMs: matchMs, totalMs: matchMs)
            return source == "wispr"   // it began with "Pilot": drop it, never type it into a text field
        case .teach(let phrase, let commands):
            return taught(learn(phrase, commands, forget: false, brain: brain, frontApp: frontApp), "teach")
        case .forget(let phrase):
            return taught(learn(phrase, [], forget: true, brain: brain, frontApp: frontApp), "forget")
        case .run(var steps):
            lastMiss = nil
            let clip = NSPasteboard.general.changeCount   // a Wispr paste's, for selectedText
            Hands.queue.async {
                if pilotApp {   // command bar: wait until focus is back on the previous app
                    let deadline = Date().addingTimeInterval(1)
                    while NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid(), Date() < deadline { usleep(20_000) }
                }
                Screen.normalize = brain.normalize   // set here so only the Hands queue touches it
                var error: String?, said: [String] = []
                if steps.contains(where: { $0.actions.contains(where: Hands.needsSelection) }) {   // read it before anything switches apps
                    if let text = Screen.selectedText(wisprClip: source == "wispr" ? clip : nil) {
                        steps = steps.map { var s = $0; s.actions = s.actions.map { Hands.withSelection($0, text) }; return s }
                    } else { error = "Select some text first" }
                }
                // Wispr puts your clipboard back ~0.5 s after its paste: anything Pilot copies before that would be lost
                if source == "wispr", steps.contains(where: { $0.actions.contains(where: Hands.writesClipboard) }) {
                    let until = Date() + 0.8
                    while NSPasteboard.general.changeCount == clip, Date() < until { usleep(20_000) }
                }
                outer: for step in steps where error == nil {
                    var note: String?
                    for action in step.actions { if let e = Hands.perform(action, note: &note) { error = e; break outer } }
                    said.append(note ?? step.say)
                }
                let totalMs = Date().timeIntervalSince(start) * 1000
                if !steps.contains(where: { $0.actions == [.help] }) {
                    let done = said.joined(separator: " → ")
                    HUD.show(error.map { "⚠︎ \($0)" } ?? (done.hasPrefix("▶") ? done : "✓ " + done))
                }
                Log.usage(source: source, text: text, matched: steps.map(\.id), ok: error == nil, error: error, matchMs: matchMs, totalMs: totalMs)
                Log.debug(String(format: "Ran %@ in %.0f ms (match %.1f ms)%@", steps.map(\.id).joined(separator: ","), totalMs, matchMs, error.map { " error: \($0)" } ?? ""))
            }
            return true
        }
    }

    func helpText() -> String {
        guard let c = brain?.config else { return "commands.json didn't load." }
        var out = "Start with \"Pilot\" when dictating with Wispr (not needed in the command bar).\nChain with commas: \"Pilot, open Chrome, new tab, search for cats\".\nAdd \"in <app>\" to run a command in another app.\n"
            + "Teach it: \"when I say focus time, do open Notion, mute\", or right after a miss \"teach that: new tab\".\n"
            + "No hands: \"start listening\", then say \"Pilot\", wait for 🎙 Listening…, and say the command: Wispr writes it. \"Pilot, dictate\" starts Wispr to type what you say next.\n"
        let groups = [nil] + Array(Set(c.commands.compactMap(\.app))).sorted()
        for app in groups {
            out += "\n" + (app ?? "Anywhere") + "\n"
            for cmd in c.commands where cmd.app == app {
                let todo = (cmd.action.keys ?? "").uppercased().hasPrefix("TODO") ? "   (not set up yet)" : ""
                out += "  • " + cmd.phrases.joined(separator: "  /  ") + todo + "\n"
            }
        }
        out += "\nMacros\n" + c.macros.filter { learned[$0.key] == nil }.sorted { $0.key < $1.key }.map { "  • \($0.key): \($0.value.joined(separator: ", "))" }.joined(separator: "\n")
        if !learned.isEmpty {
            out += "\n\nTaught by you (\"forget <phrase>\" removes one)\n" + learned.sorted { $0.key < $1.key }.map { "  • \($0.key): \($0.value.joined(separator: ", "))" }.joined(separator: "\n")
        }
        out += "\n\nWebsites (\"open github\", \"search youtube for lofi\")\n  " + (c.sites ?? [:]).keys.sorted().joined(separator: ", ")
        out += "\n\nChrome profiles (\"switch to college profile\")\n  " + Array(Set(Hands.chromeProfiles().prefix { _ in true }.map(\.key))).sorted().joined(separator: ", ")
        out += "\n\nApp names\n  " + c.apps.sorted { $0.key < $1.key }.map { "\($0.key) → \($0.value)" }.joined(separator: ", ") + ", plus any installed app by name."
        if let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid(), let name = appName(front) {
            var menus: [(String, [String])] = []   // in menu-bar order
            for p in Screen.menus(of: name, budget: 0.5) {
                let item = p.dropFirst().joined(separator: " › ")
                if let i = menus.firstIndex(where: { $0.0 == p[0] }) { menus[i].1.append(item) } else { menus.append((p[0], [item])) }
            }
            out += "\n\n\(name) menu items (say the exact title: \"Pilot, \(menus.first?.1.first ?? "new window")\")\n"
                + menus.map { "  \($0.0): \($0.1.joined(separator: ", "))" }.joined(separator: "\n")
        }
        return out
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let pilot = Pilot()
    let interceptor = PasteInterceptor()
    var statusItem: NSStatusItem!
    var hotkey = "ctrl+opt+p"

    func applicationDidFinishLaunching(_ note: Notification) {
        Screen.start()
        Hands.trackActivations()
        pilot.onLoad = { WakeWord.shared.train($0.trainingPhrases()) }
        pilot.reloadIfChanged()
        HelpWindow.shared.text = { [pilot] in pilot.helpText() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "airplane", accessibilityDescription: "Pilot")
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self

        interceptor.onWisprPaste = { [pilot] text in pilot.wisprPaste(text) }
        interceptor.onLandedPaste = { [pilot] text in pilot.landedPaste(text) }
        CommandBar.shared.onSubmit = { [pilot] text, previous in
            pilot.handle(text, source: "bar", frontApp: appName(previous), waitForFocusFrom: true)
        }
        hotkey = pilot.brain?.config.hotkey ?? hotkey
        if !Hotkey.register(hotkey, { CommandBar.shared.toggle() }) { Log.debug("Couldn't register hotkey \(hotkey)") }

        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        }
        startTapWhenTrusted()
        WakeWord.shared.onWake = { [pilot] in pilot.wakeStarted() }
        WakeWord.shared.onListening = { HUD.show("🎙 Listening…", seconds: 3) }
        WakeWord.shared.onCommand = { [pilot] spoke in pilot.wakeCommand(spoke: spoke) }
        if WakeWord.shared.isOn { WakeWord.shared.setOn(true) }
        Log.debug("Pilot started. Accessibility: \(AXIsProcessTrusted()). Terminal's Secure Keyboard Entry: "
                  + (UserDefaults(suiteName: "com.apple.Terminal")?.bool(forKey: "SecureKeyboardEntry") == true ? "on" : "off"))
    }

    /// The paste interceptor needs Accessibility; keep retrying until it's granted.
    func startTapWhenTrusted() {
        if interceptor.start() { Log.debug("Wispr paste interceptor running"); return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.startTapWhenTrusted() }
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let t = Log.today()
        menu.addItem(withTitle: "Today: \(t.ok) command\(t.ok == 1 ? "" : "s") (\(t.wispr) via Wispr)", action: nil, keyEquivalent: "")
        if AXIsProcessTrusted() && interceptor.isRunning {
            menu.addItem(withTitle: "Listening for \"Pilot, …\" in Wispr", action: nil, keyEquivalent: "")
        } else {
            menu.addItem(item("⚠︎ Grant Accessibility permission…", #selector(openAccessibility)))
        }
        if IsSecureEventInputEnabled() {
            menu.addItem(withTitle: "Secure input is on: Pilot reads Wispr from the clipboard", action: nil, keyEquivalent: "")
        }
        menu.addItem(.separator())
        let listen = item("Listen for \"Pilot\" (no key needed)", #selector(toggleListening))
        listen.state = WakeWord.shared.isOn ? .on : .off
        menu.addItem(listen)
        menu.addItem(item("Command Bar (\(hotkey))", #selector(openBar)))
        menu.addItem(item("What Can I Say?", #selector(openHelp)))
        menu.addItem(.separator())
        menu.addItem(item("Edit commands.json", #selector(editCommands)))
        menu.addItem(item("Reload Commands", #selector(reload)))
        menu.addItem(item("Show Logs in Finder", #selector(showLogs)))
        let login = item("Open at Login", #selector(toggleLogin))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)
        menu.addItem(.separator())
        menu.addItem(item("Quit Pilot", #selector(NSApplication.terminate(_:))))
    }

    private func item(_ title: String, _ action: Selector) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: "")
        i.target = action == #selector(NSApplication.terminate(_:)) ? NSApp : self
        return i
    }

    @objc func openBar() { CommandBar.shared.show() }
    @objc func toggleListening() { WakeWord.shared.setOn(!WakeWord.shared.isOn) }
    @objc func openHelp() { HelpWindow.shared.show() }
    @objc func editCommands() { NSWorkspace.shared.open(pilot.commandsURL) }
    @objc func showLogs() { NSWorkspace.shared.activateFileViewerSelecting([Log.usageURL, Log.debugURL]) }
    @objc func reload() { HUD.show(pilot.reloadIfChanged(force: true).map { "⚠︎ \($0)" } ?? "✓ Reloaded \(pilot.brain?.config.commands.count ?? 0) commands") }
    @objc func openAccessibility() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() } else { try SMAppService.mainApp.register() }
        } catch { HUD.show("⚠︎ \(error.localizedDescription)") }
    }
}

// `Pilot --run "open chrome, new tab" [--app WhatsApp]` runs one command from the terminal (for testing), then
// exits. --app pretends that app is in front. Accessibility needs `open -n -g Pilot.app --args --run …`.
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--run"), i + 1 < args.count {
    let pilot = Pilot()
    Screen.start()
    pilot.reloadIfChanged()
    Screen.testFront = args.firstIndex(of: "--app").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    let front = Screen.testFront ?? appName(NSWorkspace.shared.frontmostApplication)
    print(pilot.handle(args[i + 1], source: "cli", frontApp: front) ? "running" : "not matched")
    Hands.queue.async { DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { exit(0) } }
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
