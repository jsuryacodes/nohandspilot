// Screen: what Accessibility shows of other apps. Menu items as commands (rule 8).
import AppKit

enum Screen {
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

    // MARK: AX helpers

    static func running(_ app: String) -> NSRunningApplication? { NSWorkspace.shared.runningApplications.first { appName($0) == app } }

    static func attr(_ el: AnyObject?, _ name: String) -> AnyObject? {
        guard let el, CFGetTypeID(el) == AXUIElementGetTypeID() else { return nil }
        var v: CFTypeRef?
        return AXUIElementCopyAttributeValue(el as! AXUIElement, name as CFString, &v) == .success ? v : nil
    }

    static func children(_ el: AnyObject?) -> [AXUIElement] { attr(el, kAXChildrenAttribute) as? [AXUIElement] ?? [] }

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
