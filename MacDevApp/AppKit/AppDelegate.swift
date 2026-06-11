import AppKit
import DevAppCore

/// Hosts the AppKit-only integrations: the Services provider, the global
/// hot-key, and `devtoolkit://` deep links. Installed on the SwiftUI `App`
/// via `@NSApplicationDelegateAdaptor`.
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

    /// Handles `devtoolkit://tool/<id>?input=...` and `devtoolkit://palette`.
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let route = DeepLinkRoute.parse(url) else { continue }
            handle(route)
        }
    }

    private func handle(_ route: DeepLinkRoute) {
        Task { @MainActor in
            // The coordinator closures are installed by ContentView.onAppear —
            // wait briefly when the URL launches the app cold.
            for _ in 0..<20 where AppCoordinator.shared.route == nil {
                try? await Task.sleep(for: .milliseconds(100))
            }
            AppCoordinator.shared.activateApp()
            switch route {
            case .tool(let id, let input):
                AppCoordinator.shared.route?(input ?? "", id)
            case .palette:
                AppCoordinator.shared.openPalette?()
            }
        }
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
