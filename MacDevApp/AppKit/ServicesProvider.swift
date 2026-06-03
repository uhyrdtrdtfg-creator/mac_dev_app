import AppKit
import DevAppCore

/// Exposes DevToolkit actions in the macOS Services menu. Registered via
/// `NSApp.servicesProvider`; method names match the `NSMessage` keys in
/// Info.plist's `NSServices`.
final class ServicesProvider: NSObject {
    /// "Open in DevToolkit" — pick the best-matching tool for the selection.
    @objc func openInDevToolkit(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        let toolID = ClipboardInspector.detect(text).first?.toolID ?? "text-analyzer"
        route(text, to: toolID)
    }

    /// "Format JSON in DevToolkit".
    @objc func formatJSONInDevToolkit(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        route(text, to: "json-formatter")
    }

    /// "Decode Base64 in DevToolkit".
    @objc func decodeBase64InDevToolkit(
        _ pboard: NSPasteboard,
        userData: String?,
        error: AutoreleasingUnsafeMutablePointer<NSString?>?
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        route(text, to: "base64-codec")
    }

    private func route(_ text: String, to toolID: String) {
        Task { @MainActor in
            AppCoordinator.shared.activateApp()
            AppCoordinator.shared.route?(text, toolID)
        }
    }
}
