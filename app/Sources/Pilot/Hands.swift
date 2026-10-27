// Hands: turns the Brain's actions into macOS events. Runs on its own serial queue so waits never block the UI.
import AppKit
import PilotBrain

/// Apps are named by their .app file name ("Visual Studio Code"), never localizedName ("Code").
func appName(_ app: NSRunningApplication?) -> String? { app?.bundleURL?.deletingPathExtension().lastPathComponent }

enum Hands {
    static let queue = DispatchQueue(label: "pilot.hands")
    static var installed: [String: URL] = [:]
    static var aliases: [String: String] = [:]   // display name → file name, e.g. "OBS Studio" → "OBS"
    static var browser = "Google Chrome"
    /// Apps in activation order (newest last), for "switch back". Updated on the main thread.
    static var history: [pid_t] = []

    static func trackActivations() {
        // NSWorkspace posts these only on its own centre, never on NotificationCenter.default
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication, app.processIdentifier != getpid() else { return }
            history.removeAll { $0 == app.processIdentifier }
            history.append(app.processIdentifier)
            if history.count > 10 { history.removeFirst() }
        }
    }

    /// Chrome profiles as (spoken name, profile directory): display names first, then Google account names.
    static func chromeProfiles() -> [(key: String, value: String)] {
        let url = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Local State")
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let cache = (json["profile"] as? [String: Any])?["info_cache"] as? [String: [String: Any]] else { return [] }
        var out: [(key: String, value: String)] = []
        for field in ["name", "gaia_name", "gaia_given_name"] {
            for (dir, info) in cache.sorted(by: { $0.key < $1.key }) {
                if let name = info[field] as? String, !name.isEmpty { out.append((name, dir)) }
            }
        }
        return out
    }

    /// Installed apps by .app file name, plus their display names, one folder deep (DaVinci Resolve/…).
    static func scanApps() {
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                    "/System/Library/CoreServices", NSHomeDirectory() + "/Applications"]
        var apps: [String: URL] = [:], names: [String: String] = [:]
        func add(_ url: URL) {
            let name = url.deletingPathExtension().lastPathComponent
            guard apps[name] == nil else { return }
            apps[name] = url
            let info = NSDictionary(contentsOf: url.appendingPathComponent("Contents/Info.plist"))
            for key in ["CFBundleDisplayName", "CFBundleName"] {
                guard let alt = (info?[key] as? String)?.filter({ $0.isLetter || $0.isNumber || $0 == " " }).trimmingCharacters(in: .whitespaces),
                      !alt.isEmpty, alt != name else { continue }
                names[alt] = names[alt] ?? name
            }
        }
        for dir in dirs {
            for entry in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
                let url = URL(fileURLWithPath: dir).appendingPathComponent(entry)
                if entry.hasSuffix(".app") { add(url); continue }
                guard !dir.hasPrefix("/System"), (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                for sub in (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [] where sub.hasSuffix(".app") {
                    add(url.appendingPathComponent(sub))
                }
            }
        }
        installed = apps
        aliases = names
    }

    /// Runs on `queue`. Returns an error message, or nil on success. `note` replaces the step's toast (what was clicked).
    static func perform(_ action: Action, note: inout String?) -> String? {
        switch action {
        case .openApp(let name): return openApp(name)
        case .quitApp(let name):
            let apps = NSWorkspace.shared.runningApplications.filter { appName($0) == name }
            if apps.isEmpty { return "\(name) isn't running" }
            apps.forEach { $0.terminate() }
        case .keys(let spec):
            guard let (code, flags) = parseKeys(spec) else { return "Unknown keys \"\(spec)\"" }
            press(code, flags)
        case .type(let text): type(text)
        case .hideApp(let name):
            let apps = NSWorkspace.shared.runningApplications.filter { appName($0) == name }
            if apps.isEmpty { return "\(name) isn't running" }
            apps.forEach { $0.hide() }
        case .previousApp:
            let pids = DispatchQueue.main.sync { history }
            let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
            guard let pid = pids.last(where: { $0 != front }), let app = NSRunningApplication(processIdentifier: pid), let name = appName(app) else {
                return "No previous app yet"
            }
            return openApp(name)
        case .openURL(let s):
            guard let url = URL(string: s) else { return "Bad URL \(s)" }
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            if let app = NSWorkspace.shared.runningApplications.first(where: { appName($0) == browser })?.bundleURL ?? installed[browser] {
                NSWorkspace.shared.open([url], withApplicationAt: app, configuration: config)
                return waitForFront(browser)
            }
            NSWorkspace.shared.open(url)
        case .chromeProfile(let dir):
            // A second "open" hands the flag to the running Chrome, which opens a window in that profile.
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            p.arguments = ["-na", "Google Chrome", "--args", "--profile-directory=\(dir)"]
            do { try p.run() } catch { return "Couldn't open Chrome: \(error.localizedDescription)" }
            return waitForFront("Google Chrome")
        case .media(let key): media(key)
        case .scroll(let dir, let ticks): scroll(down: dir != "up", ticks: ticks)
        case .wait(let ms): usleep(useconds_t(ms * 1000))
        case .help: DispatchQueue.main.async { HelpWindow.shared.show() }
        case .menu(let app, let path): return Screen.pressMenu(app, path)
        case .click(let target): return Screen.click(target, note: &note)
        case .notConfigured(let note): return "Not set up yet: \(note)"
        }
        return nil
    }

    // MARK: apps

    static func openApp(_ name: String) -> String? {
        let running = NSWorkspace.shared.runningApplications.first { appName($0) == name }
        guard let url = running?.bundleURL ?? installed[name] ?? { scanApps(); return installed[name] }() else {
            return "Can't find \(name)"
        }
        // openApplication on a running app acts like clicking its Dock icon: it comes forward and
        // reopens a window if it has none (Finder).
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, _ in app?.activate() }
        return waitForFront(name)
    }

    static func waitForFront(_ name: String) -> String? {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let front = NSWorkspace.shared.frontmostApplication, appName(front) == name, frontWindow(pid: front.processIdentifier) != nil {
                usleep(120_000)   // let the window take keyboard focus
                return nil
            }
            usleep(30_000)
        }
        return "\(name) didn't come to the front"
    }

    static func frontWindow(pid: pid_t) -> CGRect? {
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        for w in list where (w[kCGWindowOwnerPID as String] as? pid_t) == pid && (w[kCGWindowLayer as String] as? Int) == 0 {
            if let b = w[kCGWindowBounds as String] as? NSDictionary, let r = CGRect(dictionaryRepresentation: b), r.width > 50 { return r }
        }
        return nil
    }

    // MARK: keyboard

    static let source = CGEventSource(stateID: .hidSystemState)

    static func press(_ code: CGKeyCode, _ flags: CGEventFlags) {
        for down in [true, false] {
            let e = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down)
            e?.flags = flags
            e?.post(tap: .cghidEventTap)
        }
        usleep(40_000)   // give the app a beat before the next step
    }

    static func type(_ text: String) {
        let units = Array(text.utf16)
        for start in stride(from: 0, to: units.count, by: 16) {
            let chunk = Array(units[start..<min(start + 16, units.count)])
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down)
                e?.flags = []
                e?.keyboardSetUnicodeString(stringLength: chunk.count, unicodeString: chunk)
                e?.post(tap: .cghidEventTap)
            }
            usleep(8_000)
        }
        usleep(40_000)
    }

    static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7, "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14,
        "r": 15, "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22, "5": 23, "=": 24, "9": 25, "7": 26, "-": 27,
        "8": 28, "0": 29, "]": 30, "o": 31, "u": 32, "[": 33, "i": 34, "p": 35, "enter": 36, "return": 36, "l": 37, "j": 38,
        "'": 39, "k": 40, ";": 41, "\\": 42, ",": 43, "/": 44, "n": 45, "m": 46, ".": 47, "tab": 48, "space": 49, "`": 50,
        "delete": 51, "backspace": 51, "esc": 53, "escape": 53, "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111, "home": 115, "pageup": 116, "forwarddelete": 117,
        "end": 119, "pagedown": 121, "left": 123, "right": 124, "down": 125, "up": 126,
    ]

    /// "cmd+shift+t" → (keycode, flags). Also used for the hotkey.
    static func parseKeys(_ spec: String) -> (CGKeyCode, CGEventFlags)? {
        var flags: CGEventFlags = []
        var code: CGKeyCode?
        // split on "+" but allow the key itself to be "+"-free punctuation like "`" or "["
        for part in spec.lowercased().split(separator: "+").map({ $0.trimmingCharacters(in: .whitespaces) }) {
            switch part {
            case "cmd", "command": flags.insert(.maskCommand)
            case "shift": flags.insert(.maskShift)
            case "opt", "option", "alt": flags.insert(.maskAlternate)
            case "ctrl", "control": flags.insert(.maskControl)
            case "fn": flags.insert(.maskSecondaryFn)
            default: code = keyCodes[part]
            }
        }
        if let c = code, [123, 124, 125, 126, 115, 116, 117, 119, 121].contains(c) { flags.insert([.maskNumericPad, .maskSecondaryFn]) }
        return code.map { ($0, flags) }
    }

    // MARK: scroll

    /// Scroll events go to the window under the pointer, so park the pointer in the front window first.
    static func scroll(down: Bool, ticks: Int) {
        if let front = NSWorkspace.shared.frontmostApplication, let r = frontWindow(pid: front.processIdentifier),
           let mouse = CGEvent(source: nil)?.location, !r.contains(mouse) {
            CGWarpMouseCursorPosition(CGPoint(x: r.midX, y: r.midY))
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        for _ in 0..<ticks {   // 80 px each: 6 ≈ half a page, 16 ≈ a page
            CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: down ? -80 : 80, wheel2: 0, wheel3: 0)?
                .post(tap: .cghidEventTap)
            usleep(12_000)
        }
    }
}

extension Hands {
    /// Hardware media keys (NX_KEYTYPE_*), so they work with Music, Spotify, YouTube in Chrome, and the volume HUD.
    static func media(_ key: String) {
        let codes: [String: Int] = ["volumeUp": 0, "volumeDown": 1, "mute": 7, "play": 16, "next": 17, "previous": 18]
        guard let code = codes[key] else { return }
        for down in [true, false] {
            let ev = NSEvent.otherEvent(with: .systemDefined, location: .zero, modifierFlags: NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00),
                                        timestamp: 0, windowNumber: 0, context: nil, subtype: 8,
                                        data1: (code << 16) | ((down ? 0xA : 0xB) << 8), data2: -1)
            ev?.cgEvent?.post(tap: .cghidEventTap)
        }
        usleep(40_000)
    }
}
