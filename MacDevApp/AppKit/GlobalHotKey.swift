import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hot-key via Carbon's `RegisterEventHotKey`,
/// which works without Accessibility permission and does not require sandbox
/// exceptions. Only one shortcut is active at a time.
@MainActor
final class GlobalHotKey {
    static let shared = GlobalHotKey()
    private init() {}

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var action: (() -> Void)?

    /// 'DTKY' — our hot-key signature.
    private let signature: OSType = 0x44544B59

    /// Replace any existing registration with `shortcut` → `action`.
    func register(_ shortcut: HotKeyShortcut, action: @escaping () -> Void) {
        unregister()
        self.action = action

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(GetApplicationEventTarget(), hotKeyEventHandler, 1, &spec, nil, &eventHandler)

        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
        if let eventHandler { RemoveEventHandler(eventHandler) }
        eventHandler = nil
        action = nil
    }

    fileprivate func fire() { action?() }
}

/// Top-level C callback (no captured state) invoked when the hot-key fires.
private func hotKeyEventHandler(
    _ next: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    DispatchQueue.main.async {
        MainActor.assumeIsolated { GlobalHotKey.shared.fire() }
    }
    return noErr
}
