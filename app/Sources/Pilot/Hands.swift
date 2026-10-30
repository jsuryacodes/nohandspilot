// Hands: turns the Brain's actions into macOS events. Runs on its own serial queue so waits never block the UI.
import AppKit
import CoreServices
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
            if url.scheme?.hasPrefix("http") == true,   // Settings panes, dict: … go to their own app
               let app = NSWorkspace.shared.runningApplications.first(where: { appName($0) == browser })?.bundleURL ?? installed[browser] {
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
        case .media(let key): media(key, note: &note)
        case .scroll(let dir, let ticks): return scroll(dir, ticks: ticks)
        case .wait(let ms): usleep(useconds_t(ms * 1000))
        case .help: DispatchQueue.main.async { HelpWindow.shared.show() }
        case .menu(let app, let path): return Screen.pressMenu(app, path)
        case .click(let target): return Screen.click(target, note: &note)
        case .numbers(let on): return Screen.numbers(on, note: &note)
        case .playMusic(let query): return playMusic(query, note: &note)
        case .copyLink(let target): return Screen.click(target, link: true, note: &note)
        case .selectText(let phrase, let op, let click):
            guard let selected = Screen.selectInField(phrase) else {
                return op == "select" ? Screen.click(click, note: &note) : "No text field here with \"\(phrase)\" in it"
            }
            usleep(50_000)
            switch op {
            case "delete": press(51, [])
            case "cut": press(7, .maskCommand)    // X
            case "copy": press(8, .maskCommand)   // C
            default: break
            }
            note = ["delete": "Deleted", "cut": "Cut", "copy": "Copied"][op, default: "Selected"] + " \"\(selected)\""
        case .listen(let on): DispatchQueue.main.async { WakeWord.shared.setOn(on) }
        case .dictate: DispatchQueue.main.async { WakeWord.shared.dictate() }
        case .openFile(let name, let folder, let reveal):
            let start = Date()
            guard let url = name.hasPrefix("/") ? URL(fileURLWithPath: name) : spotlight(name, folder: folder) else {
                return "No \(folder ? "folder" : "file") called \"\(name)\" in your home folder"
            }
            Log.debug(String(format: "Found %@ for \"%@\" in %.0f ms", url.path, name, Date().timeIntervalSince(start) * 1000))
            if reveal { NSWorkspace.shared.activateFileViewerSelecting([url]) } else { NSWorkspace.shared.open(url) }
            note = (reveal ? "Showing " : "Opened ") + url.lastPathComponent
                + (name.hasPrefix("/") ? "" : " from " + url.deletingLastPathComponent().lastPathComponent)
        case .notConfigured(let note): return "Not set up yet: \(note)"
        }
        return nil
    }

    // MARK: files

    /// Spoken name → path, for "open downloads" from any app.
    static func knownFolders() -> [(key: String, value: String)] {
        let home = NSHomeDirectory()
        return [("downloads", home + "/Downloads"), ("documents", home + "/Documents"), ("desktop", home + "/Desktop"),
                ("home", home), ("applications", "/Applications")]
    }

    /// The most recently used item under the home folder whose name has every word of `name` as a whole word,
    /// ignoring case and accents (Spotlight). Whole words, not substrings: "irs" mustn't match "first", and a
    /// substring query for "a" took 47 s here (whole word: under 1 s). Skips ~/Library, hidden folders, node_modules.
    static func spotlight(_ name: String, folder: Bool) -> URL? {
        let words = name.split(separator: " ").map { $0.filter { !"\"\\*?".contains($0) } }.filter { !$0.isEmpty }
        guard !words.isEmpty else { return nil }
        let query = words.map { "kMDItemDisplayName == \"\($0)\"cdw" }.joined(separator: " && ")
            + (folder ? " && kMDItemContentType == \"public.folder\"" : "")
        guard let q = MDQueryCreate(kCFAllocatorDefault, query as CFString, nil, nil) else { return nil }
        let home = NSHomeDirectory()
        MDQuerySetSearchScope(q, [home] as CFArray, 0)
        MDQuerySetMaxCount(q, 1000)
        guard MDQueryExecute(q, CFOptionFlags(kMDQuerySynchronous.rawValue)) else { return nil }
        var best: (url: URL, used: Date)?
        for i in 0..<MDQueryGetResultCount(q) {
            guard let raw = MDQueryGetResultAtIndex(q, i) else { continue }
            let item = Unmanaged<MDItem>.fromOpaque(raw).takeUnretainedValue()
            guard let path = MDItemCopyAttribute(item, kMDItemPath) as? String, !path.hasPrefix(home + "/Library/"),
                  !path.contains("/."), !path.contains("/node_modules/") else { continue }
            let used = (MDItemCopyAttribute(item, kMDItemLastUsedDate) ?? MDItemCopyAttribute(item, kMDItemContentModificationDate)) as? Date ?? .distantPast
            if best == nil || used > best!.used { best = (URL(fileURLWithPath: path), used) }
        }
        return best?.url
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
            // The key up has no modifiers, as if you'd let go of them. With them, macOS kept them "held" until your next
            // real key press: after Ctrl+→, fn stayed on (the wake word took every "Pilot" for Wispr's fn key, 29 Oct)
            // and so did Control (a click Pilot made next carried it).
            e?.flags = down ? flags : []
            e?.post(tap: .cghidEventTap)
        }
        usleep(40_000)   // give the app a beat before the next step
    }

    /// Deletes the last `n` characters typed or pasted, one Backspace each.
    static func backspace(_ n: Int) {
        for _ in 0..<n {
            for down in [true, false] {
                let e = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: down)
                e?.flags = []
                e?.post(tap: .cghidEventTap)
            }
            usleep(3_000)
        }
        usleep(40_000)
    }

    static func type(_ text: String) {
        if text.contains("\n") || text.count > 200 { return paste(text) }   // a typed newline would send a chat message early
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

    /// Through the clipboard, which is put back afterwards.
    static func paste(_ text: String) {
        let saved = clipboard()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        press(9, .maskCommand)   // V
        usleep(250_000)          // the app reads the clipboard in its own time
        setClipboard(saved)
    }

    /// Every item on the clipboard with all its types, in order, to put back exactly.
    static func clipboard() -> [[(NSPasteboard.PasteboardType, Data)]] {
        NSPasteboard.general.pasteboardItems?.map { item in item.types.compactMap { t in item.data(forType: t).map { (t, $0) } } } ?? []
    }

    static func setClipboard(_ items: [[(NSPasteboard.PasteboardType, Data)]]) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.writeObjects(items.map { types in
            let item = NSPasteboardItem()
            for (t, data) in types { item.setData(data, forType: t) }
            return item
        })
    }

    /// Copies, cuts or pastes: uses the clipboard.
    static func usesClipboard(_ a: Action) -> Bool {
        switch a {
        case .copyLink: return true
        case .keys(let k): return ["cmd+c", "cmd+x", "cmd+v"].contains(k)
        case .selectText(_, let op, _): return op == "copy" || op == "cut"
        default: return false
        }
    }

    /// "{selection}" in a command's URL or text, filled in once when the run starts, before any app switch.
    static func needsSelection(_ a: Action) -> Bool {
        switch a { case .openURL(let s), .type(let s): return s.contains("{selection}"); default: return false }
    }

    static func withSelection(_ a: Action, _ text: String) -> Action {
        switch a {
        case .openURL(let s):   // URL-encoded, and short enough for a URL
            let t = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(1500))
            return .openURL(s.replacingOccurrences(of: "{selection}", with: t.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? t))
        case .type(let s): return .type(s.replacingOccurrences(of: "{selection}", with: text))
        default: return a
        }
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

    /// Scroll events go to whatever is under the pointer, not to the front app, so the pointer always goes to the middle
    /// of the window you're working in first: the main content is almost always there (the page, the conversation).
    /// Not the first window on screen: in full screen that was Chrome's tab strip, so every scroll hit the tabs.
    static func scroll(_ dir: String, ticks: Int) -> String? {
        guard let app = Screen.front, let win = Screen.window(AXUIElementCreateApplication(app.processIdentifier))
                .flatMap({ Screen.rect(Screen.attr($0, kAXPositionAttribute), Screen.attr($0, kAXSizeAttribute)) }) ?? frontWindow(pid: app.processIdentifier)
        else { return "No window to scroll" }
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: win.midX, y: win.midY), mouseButton: .left)?
            .post(tap: .cghidEventTap)
        usleep(30_000)
        let (v, h): (Int32, Int32) = dir == "up" ? (80, 0) : dir == "left" ? (0, 80) : dir == "right" ? (0, -80) : (-80, 0)
        for _ in 0..<ticks {   // 80 px each: 6 ≈ half a page, 16 ≈ a page
            CGEvent(scrollWheelEvent2Source: source, units: .pixel, wheelCount: 2, wheel1: v, wheel2: h, wheel3: 0)?.post(tap: .cghidEventTap)
            usleep(12_000)
        }
        return nil
    }
}

extension Hands {
    /// Hardware media keys (NX_KEYTYPE_*), so they work with Music, Spotify, YouTube in Chrome, and the volume HUD.
    /// Play and pause first look for the player on screen (Screen.playPause), so "pause" never starts anything.
    static func media(_ key: String, note: inout String?) {
        if ["play", "pause", "playPause"].contains(key) {
            // Wispr pauses whatever is playing while it records and resumes it when it stops; act after that.
            // Tune here: 0.7 s after Pilot stops Wispr (its resume time isn't measured yet).
            let wait = DispatchQueue.main.sync { WakeWord.shared.wisprStopped }.timeIntervalSinceNow + 0.7
            if wait > 0 { usleep(useconds_t(wait * 1_000_000)) }
            if Screen.playPause(key, note: &note) { return }
        }
        let codes: [String: Int] = ["volumeUp": 0, "volumeDown": 1, "mute": 7, "play": 16, "pause": 16, "playPause": 16, "next": 17, "previous": 18]
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

extension Hands {
    /// "play Florida on Apple Music": the best match in your Music library (name equal, then starting with, then
    /// containing the words, ignoring case: "Florida" finds "Florida!!!"), played through AppleScript. Not in your
    /// library: Music's own search on Apple Music, and the first song result's play button. If that can't be pressed,
    /// the results stay on screen and the toast says so.
    static func playMusic(_ spoken: String, note: inout String?) -> String? {
        let query = spoken.replacingOccurrences(of: "^(the )?(song|track) ", with: "", options: [.regularExpression, .caseInsensitive])
        if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.apple.Music" }) {
            if let e = openApp("Music") { return e }
        }
        // Asking first never blocks: the one-time "Pilot wants to control Music" prompt would hold the Hands queue.
        var target = AEAddressDesc()
        let id = "com.apple.Music"
        _ = id.withCString { AECreateDesc(typeApplicationBundleID, $0, id.utf8.count, &target) }
        defer { AEDisposeDesc(&target) }
        // Without Automation (not asked yet, or refused), Apple Music's search still works: it needs only Accessibility.
        let ask = "allow Pilot to control Music to play from your library"
        switch AEDeterminePermissionToAutomateTarget(&target, typeWildCard, typeWildCard, false) {
        case noErr: break
        case OSStatus(errAEEventWouldRequireUserConsent):
            DispatchQueue.global().async {   // the prompt; answering it never holds up a command
                var t = AEAddressDesc()
                _ = id.withCString { AECreateDesc(typeApplicationBundleID, $0, id.utf8.count, &t) }
                _ = AEDeterminePermissionToAutomateTarget(&t, typeWildCard, typeWildCard, true)
                AEDisposeDesc(&t)
            }
            let e = playFromCatalogue(query, note: &note)
            note = note.map { $0 + ". To use your library, \(ask) (the prompt on screen)" }
            return e
        case let err:
            Log.debug("Music Automation: \(err == OSStatus(errAEEventNotPermitted) ? "refused" : "error \(err)")")
            let e = playFromCatalogue(query, note: &note)
            note = note.map { $0 + ". To use your library, \(ask): System Settings → Privacy & Security → Automation" }
            return e
        }
        let q = query.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Music"
            set lib to library playlist 1
            set hits to (every track of lib whose name is "\(q)")
            if hits is {} then set hits to (every track of lib whose name starts with "\(q)")
            if hits is {} then set hits to (every track of lib whose name contains "\(q)")
            if hits is {} then return ""
            set t to item 1 of hits
            play t
            return (name of t) & tab & (artist of t)
        end tell
        """
        let start = Date()
        var err: NSDictionary?
        let found = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue ?? ""
        Log.debug(String(format: "Music library search for \"%@\": %@ in %.0f ms", query, found.isEmpty ? "no match" : "played \"\(found.replacingOccurrences(of: "\t", with: " — "))\"", Date().timeIntervalSince(start) * 1000)
                  + (err.map { " (error \($0[NSAppleScript.errorNumber] ?? "?"))" } ?? ""))
        if !found.isEmpty {
            let parts = found.components(separatedBy: "\t")
            note = "▶ " + parts[0] + (parts.count > 1 && !parts[1].isEmpty ? " — " + parts[1] : "")
            return nil
        }
        return playFromCatalogue(query, note: &note)
    }

    /// Music's search on Apple Music, as music_search does it, then the first song in Top Results: hovering a result
    /// shows its play button (an AXCheckBox "Play"), which is pressed.
    private static func playFromCatalogue(_ query: String, note: inout String?) -> String? {
        if let e = openApp("Music") { return e }
        guard let app = Screen.running("Music") else { return "Music isn't running" }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        func all(_ el: AXUIElement, _ out: inout [AXUIElement]) { out.append(el); Screen.children(el).forEach { all($0, &out) } }
        func window() -> [AXUIElement] { var out: [AXUIElement] = []; if let w = Screen.window(root) { all(w, &out) }; return out }
        func str(_ el: AXUIElement, _ a: String) -> String? { Screen.attr(el, a) as? String }
        // search Apple Music, not your library
        if let scope = window().first(where: { str($0, kAXRoleAttribute) == kAXRadioButtonRole && str($0, kAXTitleAttribute) == "Apple Music" }),
           (Screen.attr(scope, kAXValueAttribute) as? Int) != 1 {
            AXUIElementPerformAction(scope, kAXPressAction as CFString)
        }
        press(3, .maskCommand)     // F
        usleep(250_000)
        press(0, .maskCommand)     // A: replace any earlier search
        type(query)
        press(36, [])              // Return
        // the first result whose second line is "Song · <artist>" ("Song", a narrow no-break space, "·"), up to 3 s
        func subtitle(_ cell: AXUIElement) -> String? {
            Screen.children(cell).compactMap { str($0, kAXValueAttribute) }.first { $0.split(whereSeparator: { !$0.isLetter }).first == "Song" }
        }
        var song: AXUIElement?
        let deadline = Date() + 3
        repeat {
            usleep(150_000)
            let els = window()
            let typed = els.first { str($0, kAXSubroleAttribute) == kAXSearchFieldSubrole }.flatMap { str($0, kAXValueAttribute) }
            guard typed?.lowercased() == query.lowercased() else { continue }   // results of an earlier search don't count
            var inTop = false
            for el in els {
                if str(el, kAXRoleAttribute) == kAXListRole { inTop = str(el, kAXDescriptionAttribute) == "Top Results" }
                if inTop, str(el, kAXRoleAttribute) == kAXCellRole, subtitle(el) != nil { song = el; break }
            }
        } while song == nil && Date() < deadline
        guard let song, let frame = Screen.rect(Screen.attr(song, kAXPositionAttribute), Screen.attr(song, kAXSizeAttribute)) else {
            return "No song came up for \"\(query)\" on Apple Music. The results are on screen"
        }
        CGEvent(mouseEventSource: source, mouseType: .mouseMoved, mouseCursorPosition: CGPoint(x: frame.midX, y: frame.midY), mouseButton: .left)?
            .post(tap: .cghidEventTap)
        var play: AXUIElement?
        for _ in 0..<10 where play == nil {   // the button appears under the pointer
            usleep(80_000)
            play = Screen.children(song).first { str($0, kAXRoleAttribute) == kAXCheckBoxRole }
        }
        let title = str(song, kAXDescriptionAttribute) ?? query
        guard let play, AXUIElementPerformAction(play, kAXPressAction as CFString) == .success else {
            return "Couldn't press play on \"\(title)\". The results are on screen"
        }
        let artist = subtitle(song)?.components(separatedBy: "·").last?.trimmingCharacters(in: .whitespaces.union(.init(charactersIn: "\u{202F}")))
        note = "▶ " + title + (artist.map { " — " + $0 } ?? "") + " (Apple Music)"
        return nil
    }
}
