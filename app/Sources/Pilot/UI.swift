// HUD toast (never takes focus), the command bar, and the "What can I say?" window.
import AppKit

final class HUD {
    static let shared = HUD()
    private let panel: NSPanel
    private let label = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    private init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.ignoresMouseEvents = true
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        let bg = NSVisualEffectView()
        bg.material = .hudWindow
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textColor = .labelColor
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        bg.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: bg.leadingAnchor, constant: 18),
            label.trailingAnchor.constraint(equalTo: bg.trailingAnchor, constant: -18),
            label.centerYAnchor.constraint(equalTo: bg.centerYAnchor),
        ])
        panel.contentView = bg
    }

    /// Safe to call from any thread.
    static func show(_ text: String, seconds: Double = 1.8) {
        DispatchQueue.main.async { shared.present(text, seconds: seconds) }
    }

    private func present(_ text: String, seconds: Double) {
        do {
            label.stringValue = text
            guard let screen = NSScreen.main else { return }
            let width = min(label.intrinsicContentSize.width + 36, screen.visibleFrame.width - 80)
            let frame = NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.minY + 90, width: width, height: 46)
            panel.setFrame(frame, display: true)
            panel.alphaValue = 1
            panel.orderFrontRegardless()
            hideWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                NSAnimationContext.runAnimationGroup({ $0.duration = 0.25; self?.panel.animator().alphaValue = 0 }) { self?.panel.orderOut(nil) }
            }
            hideWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
    }
}

/// Small text field you can dictate into with Wispr or type into. Pasted/dictated text runs by itself.
final class CommandBar: NSObject, NSTextFieldDelegate {
    static let shared = CommandBar()
    var onSubmit: (_ text: String, _ previousApp: NSRunningApplication?) -> Void = { _, _ in }

    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
        override func cancelOperation(_ sender: Any?) { CommandBar.shared.close() }
    }
    private let panel = Panel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 56), styleMask: [.borderless], backing: .buffered, defer: false)
    private let field = NSTextField()
    private var previousApp: NSRunningApplication?
    private var lastLength = 0
    private var autoSubmit: DispatchWorkItem?

    private override init() {
        super.init()
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let bg = NSVisualEffectView(frame: panel.contentRect(forFrameRect: panel.frame))
        bg.material = .popover
        bg.state = .active
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 14
        let mark = NSImageView(frame: NSRect(x: 14, y: 14, width: 28, height: 28))
        mark.image = NSApp.applicationIconImage
        mark.autoresizingMask = [.maxXMargin]
        bg.addSubview(mark)
        field.frame = NSRect(x: 50, y: 12, width: bg.bounds.width - 66, height: bg.bounds.height - 24)
        field.autoresizingMask = [.width, .height]
        field.font = .systemFont(ofSize: 22)
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.placeholderString = "Say or type a command, e.g. open Chrome, new tab"
        field.delegate = self
        field.target = self
        field.action = #selector(submit)
        bg.addSubview(field)
        panel.contentView = bg
    }

    func toggle() { panel.isVisible ? close() : show() }

    func show() {
        let front = NSWorkspace.shared.frontmostApplication
        previousApp = front?.processIdentifier == getpid() ? previousApp : front
        field.stringValue = ""
        lastLength = 0
        if let screen = NSScreen.main {
            let f = screen.visibleFrame
            panel.setFrameOrigin(NSPoint(x: f.midX - panel.frame.width / 2, y: f.minY + f.height * 0.68))
        }
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(field)
    }

    func close() {
        autoSubmit?.cancel()
        panel.orderOut(nil)
        previousApp?.activate()
    }

    @objc private func submit() {
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        close()
        if !text.isEmpty { onSubmit(text, previousApp) }
    }

    // Typing adds one character at a time; Wispr pastes the whole phrase at once. Run those automatically.
    func controlTextDidChange(_ obj: Notification) {
        let length = field.stringValue.count
        defer { lastLength = length }
        autoSubmit?.cancel()
        guard length - lastLength >= 4 else { return }
        let work = DispatchWorkItem { [weak self] in self?.submit() }
        autoSubmit = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }
}

/// "Show numbers": a badge on everything clickable in the front app. One transparent, click-through panel per
/// screen, above everything (full-screen apps and other Spaces too). Main thread only.
final class NumberOverlay {
    static let shared = NumberOverlay()
    private(set) var isShown = false
    var count: Int { elements.count }
    private var elements: [Screen.Element] = []
    private var pid: pid_t = 0
    private var panels: [NSPanel] = []
    private var hideWork: DispatchWorkItem?

    private init() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            // another app came forward: the numbers no longer point at anything (Pilot's own command bar is fine)
            guard let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier,
                  pid != getpid(), pid != self?.pid else { return }
            self?.hide()
        }
    }

    /// Elements in global top-left coordinates, already in badge order (1 = first).
    func show(_ els: [Screen.Element], pid: pid_t) {
        hide()
        elements = els
        self.pid = pid
        isShown = true
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for screen in NSScreen.screens {
            let view = BadgeView(frame: NSRect(origin: .zero, size: screen.frame.size))
            for (i, e) in els.enumerated() {
                // Accessibility: origin top-left of the primary screen, y down. AppKit: bottom-left, y up.
                let p = NSPoint(x: e.frame.minX - screen.frame.minX, y: primaryHeight - e.frame.minY - screen.frame.minY)
                if view.bounds.insetBy(dx: -1, dy: -1).contains(p) { view.badges.append((String(i + 1), p)) }
            }
            guard !view.badges.isEmpty else { continue }
            let panel = NSPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .screenSaver
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
            panel.contentView = view
            panel.orderFrontRegardless()
            panels.append(panel)
        }
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 20, execute: work)
    }

    func hide() {
        hideWork?.cancel()
        panels.forEach { $0.orderOut(nil) }
        panels = []
        elements = []
        isShown = false
    }

    /// The element behind badge `n`, clearing the badges; nil (badges stay) if there's no such number.
    func take(_ n: Int) -> Screen.Element? {
        guard elements.indices.contains(n - 1) else { return nil }
        defer { hide() }
        return elements[n - 1]
    }

    private final class BadgeView: NSView {
        var badges: [(label: String, topLeft: NSPoint)] = []
        private let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold), .foregroundColor: NSColor.black]

        override func draw(_ dirtyRect: NSRect) {
            for (label, p) in badges {
                let size = (label as NSString).size(withAttributes: attrs)
                let w = size.width + 8, h = size.height + 2
                let box = NSRect(x: min(max(p.x, 0), bounds.width - w), y: min(max(p.y - h, 0), bounds.height - h), width: w, height: h)
                let path = NSBezierPath(roundedRect: box, xRadius: 4, yRadius: 4)
                NSColor.systemYellow.setFill()
                path.fill()
                NSColor.black.withAlphaComponent(0.6).setStroke()
                path.stroke()
                (label as NSString).draw(at: NSPoint(x: box.minX + 4, y: box.minY + 1), withAttributes: attrs)
            }
        }
    }
}

final class HelpWindow {
    static let shared = HelpWindow()
    var text: () -> String = { "" }
    private lazy var window: NSPanel = {
        let w = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 560, height: 620), styleMask: [.titled, .closable, .resizable, .utilityWindow], backing: .buffered, defer: false)
        w.title = "What can I say?"
        w.isReleasedWhenClosed = false
        let scroll = NSTextView.scrollableTextView()
        (scroll.documentView as? NSTextView)?.isEditable = false
        (scroll.documentView as? NSTextView)?.font = .monospacedSystemFont(ofSize: 12.5, weight: .regular)
        (scroll.documentView as? NSTextView)?.textContainerInset = NSSize(width: 12, height: 12)
        w.contentView = scroll
        return w
    }()

    func show() {
        ((window.contentView as? NSScrollView)?.documentView as? NSTextView)?.string = text()
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
