// Trigger A: catch Wispr's synthetic Cmd+V, read the clipboard, swallow it when it's a Pilot command.
// Trigger A2: secure input hides that Cmd+V, so then Pilot watches the clipboard Wispr pastes from.
// Trigger B: a global hotkey (Carbon, needs no permission) that opens the command bar.
import AppKit
import Carbon

final class PasteInterceptor {
    /// Called with the clipboard text of a Wispr paste. Return true to swallow the paste.
    var onWisprPaste: (String) -> Bool = { _ in false }
    private var sessionTap: CFMachPort?
    private var appTap: CFMachPort?
    private var appTapSource: CFRunLoopSource?
    private var swallowNextVUp = false
    private var lastDecided: (timestamp: CGEventTimestamp, swallow: Bool)?
    /// Called with Wispr's text when its paste already landed (secure input hid it from the taps).
    var onLandedPaste: (String) -> Void = { _ in }
    /// The clipboard's change count at the last Wispr Cmd+V a tap saw, and the last one the clipboard watch looked at.
    private var tapSawCount = -1, watchedCount: Int?
    static let terminals: Set<String> = ["com.apple.Terminal", "com.googlecode.iterm2", "dev.warp.Warp-Stable", "com.mitchellh.ghostty",
                                         "net.kovidgoyal.kitty", "org.alacritty", "com.github.wez.wezterm"]

    var isRunning: Bool { sessionTap != nil }

    /// Fails (returns false) until Pilot has Accessibility permission.
    @discardableResult func start() -> Bool {
        guard sessionTap == nil else { return true }
        sessionTap = makeTap(pid: nil)
        guard sessionTap != nil else { return false }
        // Wispr might post its Cmd+V straight to the app (CGEventPostToPid), which skips the session
        // tap. A per-app tap on the frontmost app sees those too. The debug log says which one fired.
        NotificationCenter.default.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.retargetAppTap()
        }
        retargetAppTap()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != getpid() else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {   // the app turns secure input on as it comes forward
                Log.debug("Front: \(appName(app) ?? "?"), secure input \(IsSecureEventInputEnabled() ? "on" : "off")")
            }
        }
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in self?.watchClipboard() }
        return true
    }

    /// Secure input (Terminal's Secure Keyboard Entry, a password field) hides Wispr's Cmd+V from both taps, so its
    /// paste lands. Wispr still puts the text on the clipboard first, marked concealed (your own Cmd+C never is),
    /// and puts your clipboard back ~0.5 s after the paste. Polled only while secure input is on or a terminal is in front.
    private func watchClipboard() {
        let pb = NSPasteboard.general
        guard IsSecureEventInputEnabled() || Self.terminals.contains(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "") else {
            watchedCount = nil
            return
        }
        let count = pb.changeCount
        defer { watchedCount = count }
        guard let seen = watchedCount, count != seen, pb.types?.contains(.init("org.nspasteboard.ConcealedType")) == true,
              NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier?.lowercased().contains("wispr") == true }),
              let text = pb.string(forType: .string), !text.contains(where: \.isNewline) else { return }
        let deadline = Date() + 1
        func decide() {
            if tapSawCount == count { return }   // a tap caught the paste: already handled
            if pb.changeCount == count, Date() < deadline { DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: decide); return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [self] in   // Wispr restored your clipboard: its paste is in
                guard tapSawCount != count else { return }
                Log.debug("Wispr's paste landed unseen (secure input \(IsSecureEventInputEnabled() ? "on" : "off")), read from the clipboard")
                onLandedPaste(text)
            }
        }
        decide()
    }

    private func retargetAppTap() {
        if let src = appTapSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes) }
        if let tap = appTap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }
        appTap = nil; appTapSource = nil
        guard let front = NSWorkspace.shared.frontmostApplication, front.processIdentifier != getpid() else { return }
        appTap = makeTap(pid: front.processIdentifier)
    }

    private func makeTap(pid: pid_t?) -> CFMachPort? {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue) | CGEventMask(1 << CGEventType.keyUp.rawValue)
        let me = Unmanaged.passUnretained(self).toOpaque()
        let sessionCallback: CGEventTapCallBack = { _, type, event, refcon in
            Unmanaged<PasteInterceptor>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event, tap: "session")
        }
        let appCallback: CGEventTapCallBack = { _, type, event, refcon in
            Unmanaged<PasteInterceptor>.fromOpaque(refcon!).takeUnretainedValue().handle(type, event, tap: "frontmost-app")
        }
        let tap = pid.map { CGEvent.tapCreateForPid(pid: $0, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: appCallback, userInfo: me) }
            ?? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: sessionCallback, userInfo: me)
        guard let tap else { return nil }
        let src = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        if pid != nil { appTapSource = src }
        CGEvent.tapEnable(tap: tap, enable: true)
        return tap
    }

    private func handle(_ type: CGEventType, _ event: CGEvent, tap tapName: String) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            [sessionTap, appTap].compactMap { $0 }.forEach { CGEvent.tapEnable(tap: $0, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard event.getIntegerValueField(.keyboardEventKeycode) == 9 else { return Unmanaged.passUnretained(event) }   // V
        if type == .keyUp {
            if swallowNextVUp { swallowNextVUp = false; return nil }
            return Unmanaged.passUnretained(event)
        }
        let flags = event.flags
        guard flags.contains(.maskCommand), !flags.contains(.maskControl), !flags.contains(.maskAlternate) else { return Unmanaged.passUnretained(event) }
        // the same event can reach both taps; decide once
        if let last = lastDecided, last.timestamp == event.timestamp {
            return last.swallow ? nil : Unmanaged.passUnretained(event)
        }
        let pid = pid_t(event.getIntegerValueField(.eventSourceUnixProcessID))
        let sender = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "unknown"
        let fromWispr = sender.lowercased().contains("wispr")
        var swallow = false
        if fromWispr {
            tapSawCount = NSPasteboard.general.changeCount
            // Reading the promised clipboard item also tells Wispr the paste "succeeded", so it won't warn.
            let text = NSPasteboard.general.string(forType: .string) ?? ""
            swallow = onWisprPaste(text)
        }
        Log.debug("Cmd+V seen (\(tapName) tap) from pid \(pid) [\(sender)] → \(fromWispr ? (swallow ? "Pilot command, swallowed" : "normal dictation, passed through") : "not Wispr, ignored")")
        lastDecided = (event.timestamp, swallow)
        if swallow { swallowNextVUp = true; return nil }
        return Unmanaged.passUnretained(event)
    }
}

// MARK: hotkey

enum Hotkey {
    private static var action: () -> Void = {}
    private static var ref: EventHotKeyRef?
    private static var installed = false

    static func register(_ spec: String, _ handler: @escaping () -> Void) -> Bool {
        action = handler
        if let ref { UnregisterEventHotKey(ref) }
        guard let (code, flags) = Hands.parseKeys(spec) else { return false }
        var mods: UInt32 = 0
        if flags.contains(.maskCommand) { mods |= UInt32(cmdKey) }
        if flags.contains(.maskShift) { mods |= UInt32(shiftKey) }
        if flags.contains(.maskAlternate) { mods |= UInt32(optionKey) }
        if flags.contains(.maskControl) { mods |= UInt32(controlKey) }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        if !installed { InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in Hotkey.action(); return noErr }, 1, &spec, nil, nil) }
        installed = true
        return RegisterEventHotKey(UInt32(code), mods, EventHotKeyID(signature: OSType(0x504C_5454), id: 1), GetApplicationEventTarget(), 0, &ref) == noErr
    }
}
