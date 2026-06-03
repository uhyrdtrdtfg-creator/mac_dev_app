import SwiftUI
import AppKit

/// A click-to-record control for capturing a global keyboard shortcut.
/// Click it, then press a modifier+key combination.
struct HotKeyRecorderField: NSViewRepresentable {
    @Binding var shortcut: HotKeyShortcut

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.shortcut = shortcut
        button.onChange = { newValue in shortcut = newValue }
        return button
    }

    func updateNSView(_ nsView: RecorderButton, context: Context) {
        if !nsView.isRecording { nsView.shortcut = shortcut }
    }
}

final class RecorderButton: NSButton {
    var onChange: ((HotKeyShortcut) -> Void)?

    var shortcut: HotKeyShortcut = .default {
        didSet { refreshTitle() }
    }

    private(set) var isRecording = false {
        didSet { refreshTitle() }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(toggleRecording)
        refreshTitle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func refreshTitle() {
        title = isRecording ? "Type shortcut…" : shortcut.displayString
    }

    @objc private func toggleRecording() {
        isRecording.toggle()
        if isRecording { window?.makeFirstResponder(self) }
    }

    override var acceptsFirstResponder: Bool { true }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        return super.resignFirstResponder()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else { super.keyDown(with: event); return }

        // Escape cancels without changing the shortcut.
        if event.keyCode == UInt16(53) {
            isRecording = false
            return
        }

        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        // Require at least one modifier so the shortcut is global-safe.
        guard !mods.isEmpty else { NSSound.beep(); return }

        let captured = HotKeyShortcut(
            keyCode: UInt32(event.keyCode),
            modifierFlagsRaw: mods.rawValue,
            keyLabel: Self.keyLabel(for: event)
        )
        isRecording = false
        shortcut = captured
        captured.save()
        onChange?(captured)
        NotificationCenter.default.post(name: .hotKeyChanged, object: nil)
    }

    /// A readable label for the pressed key, ignoring modifiers.
    private static func keyLabel(for event: NSEvent) -> String {
        if let special = specialKeys[event.keyCode] { return special }
        let chars = (event.charactersIgnoringModifiers ?? "").uppercased()
        return chars.isEmpty ? "Key\(event.keyCode)" : chars
    }

    private static let specialKeys: [UInt16: String] = [
        49: "Space", 36: "Return", 48: "Tab", 51: "Delete", 53: "Esc",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
    ]
}
