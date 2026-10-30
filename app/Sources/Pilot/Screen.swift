// Screen: what Accessibility shows of other apps. Menu items as commands (rule 8), click by name.
import AppKit

enum Screen {
    /// The Brain's normaliser (rule 3), so element names compare the same way commands do.
    static var normalize: (String) -> String = { $0.lowercased() }
    /// `--run … --app X` (testing): treat X as the front app without bringing it forward.
    static var testFront: String?
    static var front: NSRunningApplication? { testFront.flatMap(running) ?? NSWorkspace.shared.frontmostApplication }
    /// Menu title paths per process, with when they were read. Main thread only.
    private static var menuCache: [pid_t: (at: Date, paths: [[String]])] = [:]
    private static var dumped: Set<String> = []

    /// Every Accessibility call gives up after 0.25 s (default 6 s), so a hung app can't stall a Wispr paste.
    static func start() { AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 0.25) }

    /// Title paths of a running app's enabled menu items, e.g. ["File", "Export as PDF…"]. Reads for at most
    /// `budget` seconds (the Wispr paste waits on this), then serves the result from cache for 30 s.
    static func menus(of app: String, budget: TimeInterval = 0.15) -> [[String]] {
        guard let pid = running(app)?.processIdentifier else { return [] }
        if let c = menuCache[pid], Date().timeIntervalSince(c.at) < 30 { return c.paths }
        let start = Date()
        let root = AXUIElementCreateApplication(pid)
        // breadth first, so every top-level menu is read before deep submenus (bookmark folders) use up the budget
        var queue = children(attr(root, kAXMenuBarAttribute)).dropFirst()   // not the Apple menu
            .compactMap { top in children(top).first.map { ($0, [attr(top, kAXTitleAttribute) as? String ?? ""]) } }
        var items: [(path: [String], keys: String)] = [], cut = false
        while !queue.isEmpty && !cut {
            let (menu, path) = queue.removeFirst()
            for item in children(menu) {
                if Date().timeIntervalSince(start) > budget { cut = true; break }
                let v = values(item, [kAXTitleAttribute, kAXEnabledAttribute, kAXChildrenAttribute, "AXMenuItemCmdChar", "AXMenuItemCmdModifiers"])
                guard let title = v[0] as? String, !title.isEmpty else { continue }   // separators
                if let sub = (v[2] as? [AXUIElement])?.first { if path.count < 4 { queue.append((sub, path + [title])) }; continue }
                if v[1] as? Bool == true { items.append((path + [title], shortcut(v[3], v[4]))) }
            }
        }
        Log.debug(String(format: "Menus of %@: %d items in %.0f ms%@", app, items.count, Date().timeIntervalSince(start) * 1000, cut ? " (budget hit, partial)" : ""))
        if !dumped.contains(app), !items.isEmpty {   // once per app: titles and shortcuts, for checking commands.json
            dumped.insert(app)
            for i in items { Log.debug("menu \(app): \(i.path.joined(separator: " › "))\(i.keys.isEmpty ? "" : " = \(i.keys)")") }
        }
        let paths = items.map(\.path)
        menuCache[pid] = (Date(), paths)
        return paths
    }

    /// Runs on the Hands queue. Walks the menu bar by title, so it never presses a stale element.
    static func pressMenu(_ app: String, _ path: [String]) -> String? {
        guard let pid = running(app)?.processIdentifier else { return "\(app) isn't running" }
        let root = AXUIElementCreateApplication(pid)
        var level = children(attr(root, kAXMenuBarAttribute)), hit: AXUIElement?
        for title in path {
            if let h = hit { level = children(children(h).first) }
            hit = level.first { attr($0, kAXTitleAttribute) as? String == title }
            if hit == nil { return "Menu item \"\(path.joined(separator: " › "))\" isn't there any more" }
        }
        let err = AXUIElementPerformAction(hit!, kAXPressAction as CFString)
        // .cannotComplete: the item opened a modal dialog and the app hasn't answered yet; it was pressed
        return err == .success || err == .cannotComplete ? nil : "Couldn't press \(path.last!) (AX error \(err.rawValue))"
    }

    // MARK: click by name

    struct Element {
        var el: AXUIElement?
        var menu: [String]? = nil   // a menu item, pressed by its title path instead
        var role: String
        var name: String
        var frame: CGRect
    }

    static let actionable: Set<String> = ["AXButton", "AXLink", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXMenuButton", "AXDisclosureTriangle",
                                          "AXRow", "AXCell", "AXTextField", "AXTextArea", "AXSearchField", "AXComboBox", "AXMenuItem", "AXMenuBarItem"]
    private static let textInputs: Set<String> = ["AXTextField", "AXTextArea", "AXSearchField", "AXComboBox"]
    private static var boosted: Set<pid_t> = []   // Hands queue only

    /// Chrome and Electron apps (Claude, VS Code) only build their web content's accessibility tree when asked.
    /// Asks once per process; true if it just did. Not for other apps: it can disturb window animations.
    static func boost(_ app: NSRunningApplication, _ root: AXUIElement) -> Bool {
        guard !boosted.contains(app.processIdentifier), let path = app.bundleURL?.path else { return false }
        let fm = FileManager.default
        let attribute = app.bundleIdentifier == "com.google.Chrome" ? "AXEnhancedUserInterface"
            : fm.fileExists(atPath: path + "/Contents/Frameworks/Electron Framework.framework") || fm.fileExists(atPath: path + "/Contents/Resources/app.asar")
            ? "AXManualAccessibility" : nil
        boosted.insert(app.processIdentifier)
        guard let attribute else { return false }
        let err = AXUIElementSetAttributeValue(root, attribute as CFString, kCFBooleanTrue)
        Log.debug("\(attribute) on \(appName(app) ?? "?"): \(err == .success ? "ok" : "AX error \(err.rawValue)")")
        return true
    }

    /// Does it answer AXPress? Apple Music's tiles ("Relax", "Feel Good") are groups that do.
    private static func pressable(_ el: AXUIElement) -> Bool {
        var actions: CFArray?
        return AXUIElementCopyActionNames(el, &actions) == .success && (actions as? [String] ?? []).contains(kAXPressAction)
    }

    /// Visible elements of the app's focused window in tree order, then its menu bar titles. Actionable ones even
    /// without a name (for numbers), named ones of any role that answer AXPress, plus plain text when `text`.
    /// Capped at 3000 nodes, depth 40, 300 ms.
    static func elements(of app: NSRunningApplication, text: Bool) -> [Element] {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        if boost(app, root) { usleep(300_000) }   // the first walk after asking can come back thin
        let start = Date()
        var out: [Element] = [], nodes = 0
        func visit(_ node: AXUIElement, _ depth: Int, _ clip: CGRect, _ owner: Int?) {
            guard nodes < 3000, depth < 40, Date().timeIntervalSince(start) < 0.3 else { return }
            nodes += 1
            let v = values(node, [kAXRoleAttribute, kAXTitleAttribute, kAXDescriptionAttribute, kAXPlaceholderValueAttribute, kAXValueAttribute,
                                  kAXChildrenAttribute, kAXPositionAttribute, kAXSizeAttribute])
            let role = v[0] as? String ?? ""
            var clip = clip, owner = owner
            if let f = rect(v[6], v[7]), f.width > 1, f.height > 1 {
                guard f.intersects(clip) else { return }   // scrolled away or outside the window, and so is everything in it
                if role == kAXScrollAreaRole { clip = clip.intersection(f) }
                let labels = textInputs.contains(role) ? v[1...3] : v[1...4]   // a text field's value is what's typed in it
                let name = labels.lazy.compactMap { ($0 as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
                if actionable.contains(role) || (!name.isEmpty && role != kAXStaticTextRole && pressable(node)) {
                    out.append(Element(el: node, role: role, name: name, frame: f.intersection(clip)))
                    owner = name.isEmpty ? out.count - 1 : nil   // unnamed: named by the text inside it (list rows, web buttons)
                } else if role == kAXStaticTextRole, !name.isEmpty {
                    if let o = owner { if out[o].name.count < 80 { out[o].name += (out[o].name.isEmpty ? "" : " ") + name } }
                    else if text { out.append(Element(el: node, role: role, name: name, frame: f.intersection(clip))) }
                }
            }
            for c in v[5] as? [AXUIElement] ?? [] { visit(c, depth + 1, clip, owner) }
        }
        if let window = window(root), let frame = rect(attr(window, kAXPositionAttribute), attr(window, kAXSizeAttribute)) { visit(window, 0, frame, nil) }
        for item in children(attr(root, kAXMenuBarAttribute)) {
            let v = values(item, [kAXTitleAttribute, kAXPositionAttribute, kAXSizeAttribute])
            if let title = v[0] as? String, !title.isEmpty, let f = rect(v[1], v[2]) { out.append(Element(el: item, role: "AXMenuBarItem", name: title, frame: f)) }
        }
        Log.debug(String(format: "Walked %@: %d nodes, %d elements in %.0f ms", appName(app) ?? "?", nodes, out.count, Date().timeIntervalSince(start) * 1000))
        return out
    }

    /// Runs on the Hands queue. `target` is normalised. Order: exact name, then name starting with it, then
    /// containing all its words; window before menus, controls before plain text. Ties: badges on just those.
    /// `link`: copy a link's address instead of pressing it (links only).
    static func click(_ target: String, link: Bool = false, note: inout String?) -> String? {
        guard let app = Screen.front, let front = appName(app), !target.isEmpty else { return link ? "No link to copy" : "Nothing to click" }
        let verb = link ? "copy link" : "click"
        // badges up: a number means that badge. Any click clears them (the screen is about to change).
        // "the second one" / "the last one" while badges are up means that badge.
        let (shown, badge, n) = DispatchQueue.main.sync { () -> (Bool, Element?, Int?) in
            let o = NumberOverlay.shared
            let n = Int(target) ?? (o.isShown ? ordinal(target, count: o.count) : nil)
            let hit = n.flatMap(o.take)
            if n == nil { o.hide() }
            return (o.isShown || hit != nil, hit, n)
        }
        if shown {
            guard let badge, let n else { return "No number \(target) on screen" }
            if link { return copyURL(badge, note: &note) }
            note = "Clicked \(n)" + (badge.name.isEmpty ? "" : " \"\(badge.name)\"")
            Log.debug("Click badge \(n) in \(front): \(badge.role) \"\(badge.name)\"")
            return press(badge, app: front)
        }
        let all = link ? elements(of: app, text: false).filter { $0.role == "AXLink" } : elements(of: app, text: true)
            + DispatchQueue.main.sync { menus(of: front) }.map { Element(el: nil, menu: $0, role: "AXMenuItem", name: $0.last ?? "", frame: .zero) }
        let named = all.map { (e: $0, n: normalize($0.name)) }.filter { !$0.n.isEmpty }
        func best(_ t: String) -> [Element] {
            let words = Set(t.split(separator: " "))
            var top: [(Element, (Int, Int, Int))] = []
            for (e, n) in named {
                guard let tier = n == t ? 0 : (n + " ").hasPrefix(t + " ") ? 1 : words.isSubset(of: n.split(separator: " ")) ? 2 : nil else { continue }
                let rank = (tier, e.menu == nil ? 0 : 1, e.role == kAXStaticTextRole ? 1 : 0)
                if let r = top.first?.1, rank > r { continue }
                if let r = top.first?.1, rank < r { top = [] }
                top.append((e, rank))
            }
            // one control often appears twice (a row and its cell; a menu item listed twice): same thing
            return top.map(\.0).reduce(into: []) { kept, e in
                let center = CGPoint(x: e.frame.midX, y: e.frame.midY)
                if !kept.contains(where: { e.menu == nil ? $0.frame.contains(center) : $0.menu == e.menu }) { kept.append(e) }
            }
        }
        var hits = best(target)
        if hits.isEmpty, let r = target.range(of: " (button|link|tab|icon|field|box|checkbox|option)$", options: .regularExpression) {
            hits = best(String(target[..<r.lowerBound]))   // "the send button"
        }
        Log.debug("\(link ? "Copy link" : "Click") \"\(target)\" in \(front): " + (hits.isEmpty ? "no match" : hits.map { "\($0.role) \"\($0.name)\"" }.joined(separator: ", ")))
        guard let hit = hits.first else { return "Couldn't find \(link ? "a link " : "")\"\(target)\" on screen" }
        if hits.count > 1 {
            // a tie: number just those, in reading order, and let you pick. Menu items have no frame to badge.
            let tied = hits.filter { $0.menu == nil }.sorted(by: readingOrder)
            guard tied.count > 1 else { return "\(hits.count) matches for \"\(target)\". Say \"show numbers\"" }
            DispatchQueue.main.sync { NumberOverlay.shared.show(tied, pid: app.processIdentifier) }
            note = "\(tied.count) × \"\(hit.name)\": say " + (tied.count == 2 ? "\"\(verb) 1\" or \"\(verb) 2\"" : "\"\(verb) 1\" to \"\(verb) \(tied.count)\"")
            return nil
        }
        if link { return copyURL(hit, note: &note) }
        note = "Clicked \"\(hit.name)\""
        return press(hit, app: front)
    }

    /// A link's address (AXURL) to the clipboard.
    static func copyURL(_ e: Element, note: inout String?) -> String? {
        guard let el = e.el, let url = (attr(el, "AXURL") as? URL)?.absoluteString else { return "\"\(e.name)\" isn't a link" }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        note = "Copied link: \(url)"
        return nil
    }

    /// "select hello world" in the focused text field: selects the phrase (ignoring case; of several, the one nearest
    /// before the caret) by setting the field's selected range. Returns what was selected, or nil if the focused
    /// element isn't an editable field with that text (a web page you can't edit isn't).
    static func selectInField(_ phrase: String) -> String? {
        guard let app = front else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        if boost(app, root) { usleep(300_000) }
        var settable: DarwinBoolean = false
        guard let field = element(attr(root, kAXFocusedUIElementAttribute)), let text = attr(field, kAXValueAttribute) as? String,
              AXUIElementIsAttributeSettable(field, kAXSelectedTextRangeAttribute as CFString, &settable) == .success, settable.boolValue else {
            Log.debug("Select \"…\": the focused element isn't an editable text field")
            return nil
        }
        let ns = text as NSString
        var caret = CFRange(location: ns.length, length: 0)
        if let v = attr(field, kAXSelectedTextRangeAttribute), CFGetTypeID(v) == AXValueGetTypeID() { AXValueGetValue(v as! AXValue, .cfRange, &caret) }
        // as spoken, then without a leading "the"
        for p in [phrase, phrase.replacingOccurrences(of: "^the ", with: "", options: [.regularExpression, .caseInsensitive])] where !p.isEmpty {
            var hits: [NSRange] = [], from = 0
            while from < ns.length {
                let r = ns.range(of: p, options: .caseInsensitive, range: NSRange(location: from, length: ns.length - from))
                if r.location == NSNotFound { break }
                hits.append(r)
                from = r.location + 1
            }
            guard let hit = hits.last(where: { $0.location < caret.location }) ?? hits.first else { continue }
            var range = CFRange(location: hit.location, length: hit.length)
            guard let value = AXValueCreate(.cfRange, &range),
                  AXUIElementSetAttributeValue(field, kAXSelectedTextRangeAttribute as CFString, value) == .success else { return nil }
            Log.debug("Selected \(hit.length) characters in the text field (\(hits.count) match\(hits.count == 1 ? "" : "es"))")
            return ns.substring(with: hit)
        }
        Log.debug("Select: the text field (\(ns.length) characters) doesn't contain it")
        return nil
    }

    /// Top to bottom (rows of 12 pt), then left to right: how badges are numbered.
    static func readingOrder(_ a: Element, _ b: Element) -> Bool { (Int(a.frame.minY / 12), a.frame.minX) < (Int(b.frame.minY / 12), b.frame.minX) }

    /// "first one", "second", "the last one" (normalised) → a badge number, of `count` badges.
    static func ordinal(_ t: String, count: Int) -> Int? {
        let words = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth"]
        let w = t.hasSuffix(" one") ? String(t.dropLast(4)) : t
        return w == "last" ? (count > 0 ? count : nil) : words.firstIndex(of: w).map { $0 + 1 }
    }

    /// "play" / "pause" / "playPause" on the player in the front window (YouTube, Netflix, Spotify, Music, QuickTime): its
    /// button is named for what it does now ("Pause (k)", "Pause keyboard shortcut k" while playing), so "pause" on a paused
    /// video presses nothing. False if there's no such button: the media key then goes to whatever plays in the background.
    static func playPause(_ want: String, note: inout String?) -> Bool {
        guard let app = front, let name = appName(app) else { return false }
        let extra: Set<Substring> = ["k", "keyboard", "shortcut", "video", "button", "space", "spacebar"]
        let buttons = elements(of: app, text: false).compactMap { e -> (Element, Bool)? in   // (button, it pauses)
            let words = normalize(e.name).split(separator: " ")
            guard e.role == kAXButtonRole, let first = words.first, first == "play" || first == "pause", words.dropFirst().allSatisfy(extra.contains) else { return nil }
            return (e, first == "pause")
        }
        guard let (button, pauses) = buttons.first(where: { want == "playPause" || $0.1 == (want == "pause") }) ?? buttons.first else { return false }
        Log.debug("Player button in \(name): \"\(button.name)\" (\(buttons.count) found)")
        if want != "playPause", pauses != (want == "pause") { note = pauses ? "Already playing" : "Already paused"; return true }
        _ = press(button, app: name)
        note = pauses ? "Paused" : "Playing"
        return true
    }

    /// Badges on every actionable element of the front window and the menu bar, top to bottom, left to right.
    static func numbers(_ on: Bool, note: inout String?) -> String? {
        guard on else { DispatchQueue.main.sync { NumberOverlay.shared.hide() }; return nil }
        guard let app = Screen.front else { return "No app in front" }
        var corners: [CGPoint] = []
        let els = elements(of: app, text: false)
            .sorted(by: readingOrder)
            .filter { e in   // a row and its cell share a corner: one badge is enough
                if corners.contains(where: { abs($0.x - e.frame.minX) < 8 && abs($0.y - e.frame.minY) < 8 }) { return false }
                corners.append(e.frame.origin)
                return true
            }
        guard !els.isEmpty else { return "Nothing to number in \(appName(app) ?? "this app")" }
        DispatchQueue.main.sync { NumberOverlay.shared.show(els, pid: app.processIdentifier) }
        note = "\(els.count) numbers. Say \"click\" and a number"
        return nil
    }

    /// AXPress when the element supports it, else a real click at its centre (text fields always: that focuses them).
    static func press(_ e: Element, app: String) -> String? {
        if let path = e.menu { return pressMenu(app, path) }
        if let el = e.el, !textInputs.contains(e.role), AXUIElementPerformAction(el, kAXPressAction as CFString) == .success { return nil }
        let p = CGPoint(x: e.frame.midX, y: e.frame.midY)
        for type in [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp] {
            CGEvent(mouseEventSource: Hands.source, mouseType: type, mouseCursorPosition: p, mouseButton: .left)?.post(tap: .cghidEventTap)
            usleep(30_000)
        }
        return nil
    }

    // MARK: selection

    /// The front app's selected text: Accessibility first (the clipboard isn't touched), else Cmd+C, putting the
    /// clipboard back exactly. `wisprClip`: the clipboard's change count when a Wispr paste was swallowed. Wispr
    /// restores your clipboard right after its paste, so the copy waits for that first.
    static func selectedText(wisprClip: Int?) -> String? {
        guard let app = front else { return nil }
        let root = AXUIElementCreateApplication(app.processIdentifier)
        if boost(app, root) { usleep(300_000) }
        func real(_ s: String?) -> String? { s?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? s : nil }
        if let focused = element(attr(root, kAXFocusedUIElementAttribute)) {
            if let s = real(attr(focused, kAXSelectedTextAttribute) as? String) { return s }
            var out: CFTypeRef?   // web pages (Chrome, Safari) keep the selection as a text-marker range
            if let range = attr(focused, "AXSelectedTextMarkerRange"),
               AXUIElementCopyParameterizedAttributeValue(focused, "AXStringForTextMarkerRange" as CFString, range, &out) == .success,
               let s = real(out as? String) { return s }
        }
        let pb = NSPasteboard.general
        if let clip = wisprClip { let until = Date() + 0.6; while pb.changeCount == clip, Date() < until { usleep(20_000) } }
        let saved = Hands.clipboard(), before = pb.changeCount
        Hands.press(8, .maskCommand)   // C
        let until = Date() + 0.4
        while pb.changeCount == before, Date() < until { usleep(15_000) }
        guard pb.changeCount != before else { return nil }   // nothing selected: nothing was copied, nothing to put back
        let copied = pb.string(forType: .string)
        Hands.setClipboard(saved)
        Log.debug("Selection read by copying (\(copied?.count ?? 0) characters)")
        return real(copied)
    }

    // MARK: AX helpers

    static func running(_ app: String) -> NSRunningApplication? { NSWorkspace.shared.runningApplications.first { appName($0) == app } }

    static func attr(_ el: AnyObject?, _ name: String) -> AnyObject? {
        guard let el, CFGetTypeID(el) == AXUIElementGetTypeID() else { return nil }
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el as! AXUIElement, name as CFString, &v) == .success ? v : nil
    }

    static func children(_ el: AnyObject?) -> [AXUIElement] { attr(el, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

    /// The window you're working in: focused, else main, else any. Not the first one on screen: full-screen Chrome
    /// puts its tab strip in a thin window of its own that comes first.
    static func window(_ root: AXUIElement) -> AXUIElement? {
        [kAXFocusedWindowAttribute, kAXMainWindowAttribute].lazy.compactMap { element(attr(root, $0)) }.first
            ?? (attr(root, kAXWindowsAttribute) as? [AXUIElement])?.first
    }

    static func element(_ v: AnyObject?) -> AXUIElement? {
        guard let v, CFGetTypeID(v) == AXUIElementGetTypeID() else { return nil }
        return (v as! AXUIElement)
    }

    /// Frame in global top-left coordinates (the same ones CGEvent clicks use).
    static func rect(_ pos: Any?, _ size: Any?) -> CGRect? {
        guard let p = pos as AnyObject?, let s = size as AnyObject?, CFGetTypeID(p) == AXValueGetTypeID(), CFGetTypeID(s) == AXValueGetTypeID() else { return nil }
        var o = CGPoint.zero, z = CGSize.zero
        guard AXValueGetValue(p as! AXValue, .cgPoint, &o), AXValueGetValue(s as! AXValue, .cgSize, &z) else { return nil }
        return CGRect(origin: o, size: z)
    }

    /// Several attributes in one round trip; missing ones come back as non-matching placeholders.
    static func values(_ el: AXUIElement, _ names: [String]) -> [Any?] {
        var out: CFArray?
        guard AXUIElementCopyMultipleAttributeValues(el, names as CFArray, [], &out) == .success, let arr = out as? [Any], arr.count == names.count else {
            return Array(repeating: nil, count: names.count)
        }
        return arr
    }

    /// "cmd+shift+t" from a menu item's key equivalent (modifier bits: 1 shift, 2 option, 4 control, 8 no command).
    private static func shortcut(_ char: Any?, _ mods: Any?) -> String {
        guard let c = char as? String, !c.isEmpty else { return "" }
        let m = mods as? Int ?? 0
        return ([m & 4 != 0 ? "ctrl" : nil, m & 2 != 0 ? "opt" : nil, m & 1 != 0 ? "shift" : nil, m & 8 == 0 ? "cmd" : nil].compactMap { $0 } + [c.lowercased()])
            .joined(separator: "+")
    }
}
