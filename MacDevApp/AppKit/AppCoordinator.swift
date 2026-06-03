import AppKit
import SwiftUI

/// Bridges AppKit entry points (global hot-key, Services menu) to SwiftUI state.
/// The SwiftUI `App` assigns these closures once `ToolRegistry`/`ToolHandoff`
/// exist; AppKit callers invoke them without knowing about SwiftUI.
@MainActor
final class AppCoordinator {
    static let shared = AppCoordinator()
    private init() {}

    /// Open the ⌘K command palette in the main window.
    var openPalette: (() -> Void)?
    /// Send `text` into `toolID` (selects the tool and pre-fills its input).
    var route: ((_ text: String, _ toolID: String) -> Void)?
    /// Trigger a Sparkle update check.
    var checkForUpdates: (() -> Void)?

    /// Bring the app (and a main window) to the front.
    func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension Notification.Name {
    /// Posted when the user changes the global hot-key in Settings.
    static let hotKeyChanged = Notification.Name("devtoolkit.hotKeyChanged")
    /// Posted to ask the main window to show the command palette.
    static let openCommandPalette = Notification.Name("devtoolkit.openCommandPalette")
}

/// Bring the app forward, reusing the existing main window if there is one,
/// otherwise opening a fresh one. Avoids spawning duplicate `WindowGroup` windows.
@MainActor
func showMainWindow(using openWindow: OpenWindowAction) {
    NSApp.activate(ignoringOtherApps: true)
    if let existing = NSApp.windows.first(where: {
        $0.isVisible && $0.styleMask.contains(.titled) && $0.canBecomeMain
    }) {
        existing.makeKeyAndOrderFront(nil)
    } else {
        openWindow(id: "main")
    }
}
