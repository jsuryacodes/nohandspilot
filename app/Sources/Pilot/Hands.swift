// Hands: turns the Brain's actions into macOS events. Runs on its own serial queue so waits never block the UI.
import AppKit
import PilotBrain

/// Apps are named by their .app file name ("Visual Studio Code"), never localizedName ("Code").
func appName(_ app: NSRunningApplication?) -> String? { app?.bundleURL?.deletingPathExtension().lastPathComponent }

enum Hands {
    static let queue = DispatchQueue(label: "pilot.hands")
    static var installed: [String: URL] = scanApps()

    static func scanApps() -> [String: URL] {
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications", "/System/Applications/Utilities",
                    "/System/Library/CoreServices", NSHomeDirectory() + "/Applications"]
        var out: [String: URL] = [:]
        for dir in dirs {
            for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] where name.hasSuffix(".app") {
                out[String(name.dropLast(4))] = out[String(name.dropLast(4))] ?? URL(fileURLWithPath: dir).appendingPathComponent(name)
            }
        }
        return out
    }

    /// Runs on `queue`. Returns an error message, or nil on success.
    static func perform(_ action: Action) -> String? {
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
        case .scroll(let dir): scroll(down: dir != "up")
        case .wait(let ms): usleep(useconds_t(ms * 1000))
        case .help: DispatchQueue.main.async { HelpWindow.shared.show() }
        case .notConfigured(let note): return "Not set up yet: \(note)"
        }
        return nil
    }

    // MARK: apps

    static func openApp(_ name: String) -> String? {
        let running = NSWorkspace.shared.runningApplications.first { appName($0) == name }
        guard let url = running?.bundleURL ?? installed[name] ?? { installed = scanApps(); return installed[name] }() else {
            return "Can't find \(name)"
        }
        // openApplication on a running app acts like clicking its Dock icon: it comes forward and
        // reopens a window if it has none (Finder).
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: url, configuration: config) { app, _ in app?.activate() }
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
    static func scroll(down: Bool) {
        if let front = NSWorkspace.shared.frontmostApplication, let r = frontWindow(pid: front.processIdentifier),
           let mouse = CGEvent(source: nil)?.location, !r.contains(mouse) {
            CGWarpMouseCursorPosition(CGPoint(x: r.midX, y: r.midY))
            CGAssociateMouseAndMouseCursorPosition(1)
        }
        for _ in 0..<6 {   // ponytail: fixed ~half a page; add "scroll down a lot" when wanted
            CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 1, wheel1: down ? -80 : 80, wheel2: 0, wheel3: 0)?
                .post(tap: .cghidEventTap)
            usleep(12_000)
        }
    }
}
