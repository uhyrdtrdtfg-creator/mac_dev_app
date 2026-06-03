import SwiftUI
import ServiceManagement

/// App settings: menu-bar visibility, launch-at-login, and the global hot-key.
struct SettingsView: View {
    @AppStorage("devtoolkit.showMenuBar") private var showMenuBar = true
    @State private var shortcut = HotKeyShortcut.load()
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("General") {
                Toggle("Show icon in menu bar", isOn: $showMenuBar)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in setLaunchAtLogin(newValue) }
            }

            Section("Global Hotkey") {
                HStack {
                    Text("Summon DevToolkit")
                    Spacer()
                    HotKeyRecorderField(shortcut: $shortcut)
                        .frame(width: 150, height: 24)
                }
                Text("Press it in any app to open the command palette.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440, height: 260)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Revert the toggle to the real state on failure.
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
