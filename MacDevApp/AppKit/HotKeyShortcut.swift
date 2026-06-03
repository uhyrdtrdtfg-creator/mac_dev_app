import AppKit
import Carbon.HIToolbox

/// A user-configurable global keyboard shortcut, persisted in UserDefaults.
struct HotKeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    /// Raw value of `NSEvent.ModifierFlags` (command/option/control/shift only).
    var modifierFlagsRaw: UInt
    /// Display label for the key captured at record time (e.g. "Space", "K").
    var keyLabel: String

    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlagsRaw)
    }

    /// Default: ⌥⌘Space.
    static let `default` = HotKeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifierFlagsRaw: NSEvent.ModifierFlags([.command, .option]).rawValue,
        keyLabel: "Space"
    )

    /// Carbon modifier mask for `RegisterEventHotKey`.
    var carbonModifiers: UInt32 {
        var mask: UInt32 = 0
        if modifierFlags.contains(.command) { mask |= UInt32(cmdKey) }
        if modifierFlags.contains(.option) { mask |= UInt32(optionKey) }
        if modifierFlags.contains(.control) { mask |= UInt32(controlKey) }
        if modifierFlags.contains(.shift) { mask |= UInt32(shiftKey) }
        return mask
    }

    /// Symbolic representation, e.g. "⌥⌘Space".
    var displayString: String {
        var s = ""
        if modifierFlags.contains(.control) { s += "⌃" }
        if modifierFlags.contains(.option) { s += "⌥" }
        if modifierFlags.contains(.shift) { s += "⇧" }
        if modifierFlags.contains(.command) { s += "⌘" }
        s += keyLabel
        return s
    }

    // MARK: - Persistence

    private static let storageKey = "devtoolkit.globalHotKey"

    static func load() -> HotKeyShortcut {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(HotKeyShortcut.self, from: data)
        else { return .default }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}
