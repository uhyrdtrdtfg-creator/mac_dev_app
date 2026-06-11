import Foundation

/// A parsed `devtoolkit://` deep link.
/// - `devtoolkit://tool/<tool-id>?input=<percent-encoded-text>` → `.tool`
/// - `devtoolkit://palette` → `.palette`
public enum DeepLinkRoute: Equatable, Sendable {
    case tool(id: String, input: String?)
    case palette

    public static func parse(_ url: URL) -> DeepLinkRoute? {
        guard url.scheme?.lowercased() == "devtoolkit" else { return nil }
        switch url.host()?.lowercased() {
        case "palette":
            return .palette
        case "tool":
            guard let id = url.pathComponents.dropFirst().first, !id.isEmpty else { return nil }
            let input = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first { $0.name == "input" }?
                .value
            return .tool(id: id, input: input)
        default:
            return nil
        }
    }
}
