import AppKit

/// Hosts the AppKit-only integrations: the Services provider and the global
/// hot-key. Installed on the SwiftUI `App` via `@NSApplicationDelegateAdaptor`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let services = ServicesProvider()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.servicesProvider = services
        NSUpdateDynamicServices()

        registerHotKey()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotKeyChanged),
            name: .hotKeyChanged,
            object: nil
        )
    }

    /// Reopen the main window when the Dock icon is clicked with no windows.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        true
    }

    @objc private func hotKeyChanged() {
        registerHotKey()
    }

    private func registerHotKey() {
        GlobalHotKey.shared.register(.load()) {
            AppCoordinator.shared.activateApp()
            AppCoordinator.shared.openPalette?()
        }
    }
}
