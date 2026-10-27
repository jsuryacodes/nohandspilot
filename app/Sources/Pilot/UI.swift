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
        field.frame = bg.bounds.insetBy(dx: 16, dy: 12)
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
