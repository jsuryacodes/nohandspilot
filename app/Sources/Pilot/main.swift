// Pilot: menu-bar app. Wispr is the ears, the Brain decides, Hands act.
import AppKit
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
    private var loadedAt: Date?

    /// Reloads commands.json if it changed since last time. Returns an error message if it's broken.
    @discardableResult func reloadIfChanged(force: Bool = false) -> String? {
        let mtime = (try? FileManager.default.attributesOfItem(atPath: commandsURL.path)[.modificationDate]) as? Date
        guard force || brain == nil || mtime != loadedAt else { return nil }
        do {
            if Hands.installed.isEmpty { Hands.scanApps() }
            brain = try Brain(json: Data(contentsOf: commandsURL), installedApps: Array(Hands.installed.keys), appAliases: Hands.aliases,
                              slotValues: ["profile": Hands.chromeProfiles()])
            Hands.browser = brain!.config.browser ?? Hands.browser
            loadedAt = mtime
            Log.debug("Loaded \(brain!.config.commands.count) commands from \(commandsURL.path)")
            return nil
        } catch {
            Log.debug("commands.json error: \(error)")
            return "commands.json has an error: \(error.localizedDescription)"
        }
    }

    /// Returns true if Pilot will act on the text (so a Wispr paste should be swallowed).
    @discardableResult func handle(_ text: String, source: String, frontApp: String?, waitForFocusFrom pilotApp: Bool = false) -> Bool {
        let start = Date()
        if let err = reloadIfChanged() { HUD.show("⚠︎ \(err)"); return false }
        guard let brain else { return false }
        let plan = brain.plan(text, frontmostApp: frontApp, requireTrigger: source == "wispr")
        let matchMs = Date().timeIntervalSince(start) * 1000
        switch plan {
        case .notForPilot:
            return false
        case .unmatched(let segment, let suggestion):
            HUD.show("Didn't catch \"\(segment.isEmpty ? text : segment)\"" + (suggestion.map { ". Try \"\($0)\"" } ?? ""), seconds: 3)
            Log.usage(source: source, text: text, matched: [], ok: false, error: "unmatched: \(segment)", matchMs: matchMs, totalMs: matchMs)
            return false
        case .run(let steps):
            Hands.queue.async {
                if pilotApp {   // command bar: wait until focus is back on the previous app
                    let deadline = Date().addingTimeInterval(1)
                    while NSWorkspace.shared.frontmostApplication?.processIdentifier == getpid(), Date() < deadline { usleep(20_000) }
                }
                var error: String?
                outer: for step in steps { for action in step.actions { if let e = Hands.perform(action) { error = e; break outer } } }
                let totalMs = Date().timeIntervalSince(start) * 1000
                if !steps.contains(where: { $0.actions == [.help] }) {
                    HUD.show(error.map { "⚠︎ \($0)" } ?? "✓ " + steps.map(\.say).joined(separator: " → "))
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
        let groups = [nil] + Array(Set(c.commands.compactMap(\.app))).sorted()
        for app in groups {
            out += "\n" + (app ?? "Anywhere") + "\n"
            for cmd in c.commands where cmd.app == app {
                let todo = (cmd.action.keys ?? "").uppercased().hasPrefix("TODO") ? "   (not set up yet)" : ""
                out += "  • " + cmd.phrases.joined(separator: "  /  ") + todo + "\n"
            }
        }
        out += "\nMacros\n" + c.macros.sorted { $0.key < $1.key }.map { "  • \($0.key): \($0.value.joined(separator: ", "))" }.joined(separator: "\n")
        out += "\n\nWebsites (\"open github\", \"search youtube for lofi\")\n  " + (c.sites ?? [:]).keys.sorted().joined(separator: ", ")
        out += "\n\nChrome profiles (\"switch to college profile\")\n  " + Array(Set(Hands.chromeProfiles().prefix { _ in true }.map(\.key))).sorted().joined(separator: ", ")
        out += "\n\nApp names\n  " + c.apps.sorted { $0.key < $1.key }.map { "\($0.key) → \($0.value)" }.joined(separator: ", ") + ", plus any installed app by name."
        return out
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let pilot = Pilot()
    let interceptor = PasteInterceptor()
    var statusItem: NSStatusItem!
    var hotkey = "ctrl+opt+p"

    func applicationDidFinishLaunching(_ note: Notification) {
        Hands.trackActivations()
        pilot.reloadIfChanged()
        HelpWindow.shared.text = { [pilot] in pilot.helpText() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "airplane", accessibilityDescription: "Pilot")
        statusItem.menu = NSMenu()
        statusItem.menu?.delegate = self

        interceptor.onWisprPaste = { [pilot] text in
            pilot.handle(text, source: "wispr", frontApp: appName(NSWorkspace.shared.frontmostApplication))
        }
        CommandBar.shared.onSubmit = { [pilot] text, previous in
            pilot.handle(text, source: "bar", frontApp: appName(previous), waitForFocusFrom: true)
        }
        hotkey = pilot.brain?.config.hotkey ?? hotkey
        if !Hotkey.register(hotkey, { CommandBar.shared.toggle() }) { Log.debug("Couldn't register hotkey \(hotkey)") }

        if !AXIsProcessTrusted() {
            AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        }
        startTapWhenTrusted()
        Log.debug("Pilot started. Accessibility: \(AXIsProcessTrusted())")
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
        menu.addItem(.separator())
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

// `Pilot --run "open chrome, new tab"` runs one command from the terminal (for testing), then exits.
let args = CommandLine.arguments
if let i = args.firstIndex(of: "--run"), i + 1 < args.count {
    let pilot = Pilot()
    pilot.reloadIfChanged()
    print(pilot.handle(args[i + 1], source: "cli", frontApp: appName(NSWorkspace.shared.frontmostApplication)) ? "running" : "not matched")
    Hands.queue.async { DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { exit(0) } }
    RunLoop.main.run()
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
