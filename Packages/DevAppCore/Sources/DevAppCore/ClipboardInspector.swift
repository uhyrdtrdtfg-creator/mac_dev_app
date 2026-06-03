import Foundation

/// A guess about what the clipboard (or any text) contains, plus the tool that
/// can act on it. Used by the menu-bar panel and the Services menu to offer
/// "the clipboard looks like X → open it in Y" shortcuts.
public struct ClipboardSuggestion: Identifiable, Sendable, Hashable {
    public enum Kind: String, Sendable, CaseIterable {
        case jwt, json, url, uuid, color, timestamp, hex, base64
    }

    public var id: String { kind.rawValue }
    public let kind: Kind
    /// Human-facing label, e.g. "Looks like JSON".
    public let label: String
    /// Existing tool id that consumes this text (see `ContentView.toolView`).
    public let toolID: String
    /// SF Symbol matching the destination tool.
    public let icon: String

    public init(kind: Kind, label: String, toolID: String, icon: String) {
        self.kind = kind
        self.label = label
        self.toolID = toolID
        self.icon = icon
    }
}

/// Best-effort detection of a clipboard string's content type. Pure and
/// synchronous so it can be unit-tested and run on the main thread cheaply.
public enum ClipboardInspector {
    /// A hard cap so we never run the heavier checks on a huge paste.
    private static let maxLength = 1_000_000

    /// Returns suggestions ordered most-specific first. Empty for blank/oversized input.
    public static func detect(_ raw: String) -> [ClipboardSuggestion] {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= maxLength else { return [] }

        var out: [ClipboardSuggestion] = []

        // JWT and JSON are mutually exclusive and the most specific structural matches.
        if isJWT(text) {
            out.append(.init(kind: .jwt, label: "Looks like a JWT", toolID: "jwt", icon: "key.horizontal"))
        } else if isJSON(text) {
            out.append(.init(kind: .json, label: "Looks like JSON", toolID: "json-formatter", icon: "curlybraces"))
        }

        if isUUID(text) {
            out.append(.init(kind: .uuid, label: "Looks like a UUID", toolID: "uuid-generator", icon: "number"))
        }
        if isURL(text) {
            out.append(.init(kind: .url, label: "Looks like a URL", toolID: "url-codec", icon: "link"))
        }
        if isColor(text) {
            out.append(.init(kind: .color, label: "Looks like a color", toolID: "color-converter", icon: "paintpalette"))
        }

        let timestamp = isTimestamp(text)
        if timestamp {
            out.append(.init(kind: .timestamp, label: "Looks like a Unix timestamp", toolID: "timestamp-converter", icon: "clock"))
        }
        // Pure decimal digits already covered by the timestamp branch; don't double-flag as hex.
        if !timestamp, isHex(text) {
            out.append(.init(kind: .hex, label: "Looks like hex bytes", toolID: "hex-ascii", icon: "number.square"))
        }

        // Base64 is the broadest match — only offer it when nothing more specific won.
        if out.isEmpty, isBase64(text) {
            out.append(.init(kind: .base64, label: "Looks like Base64", toolID: "base64-codec", icon: "doc.text"))
        }

        return out
    }

    // MARK: - Detectors

    static func isJSON(_ text: String) -> Bool {
        guard let first = text.first, first == "{" || first == "[" else { return false }
        guard let data = text.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }

    static func isJWT(_ text: String) -> Bool {
        guard text.hasPrefix("eyJ") else { return false }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return false }
        let charset = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        // Header and payload must be non-empty base64url; signature may be empty (alg=none).
        guard !parts[0].isEmpty, !parts[1].isEmpty else { return false }
        for part in parts where !part.isEmpty {
            if String(part).rangeOfCharacter(from: charset.inverted) != nil { return false }
        }
        return true
    }

    static func isUUID(_ text: String) -> Bool {
        UUID(uuidString: text) != nil
    }

    static func isURL(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: text)?.host != nil
        }
        // Percent-encoded text without a scheme is still worth sending to the URL codec.
        return text.range(of: "%[0-9A-Fa-f]{2}", options: .regularExpression) != nil
    }

    static func isColor(_ text: String) -> Bool {
        let lower = text.lowercased()
        if lower.hasPrefix("rgb(") || lower.hasPrefix("rgba(") ||
           lower.hasPrefix("hsl(") || lower.hasPrefix("hsla(") {
            return lower.hasSuffix(")")
        }
        // Hex color requires a leading '#' so it doesn't collide with raw hex bytes.
        guard lower.hasPrefix("#") else { return false }
        let body = lower.dropFirst()
        let validLengths: Set<Int> = [3, 4, 6, 8]
        guard validLengths.contains(body.count) else { return false }
        return body.allSatisfy { $0.isHexDigit }
    }

    static func isTimestamp(_ text: String) -> Bool {
        guard text.count == 10 || text.count == 13, text.allSatisfy(\.isNumber) else { return false }
        guard let value = Double(text) else { return false }
        // Seconds: ~1973–2286. Milliseconds: same window ×1000.
        let seconds = text.count == 13 ? value / 1000 : value
        return seconds > 100_000_000 && seconds < 10_000_000_000
    }

    static func isHex(_ text: String) -> Bool {
        var body = text
        if body.hasPrefix("0x") || body.hasPrefix("0X") { body = String(body.dropFirst(2)) }
        body.removeAll { $0 == " " || $0 == "\n" || $0 == "\t" }
        guard body.count >= 2, body.count % 2 == 0 else { return false }
        return body.allSatisfy(\.isHexDigit)
    }

    static func isBase64(_ text: String) -> Bool {
        guard text.count >= 8, text.count % 4 == 0 else { return false }
        let charset = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")
        guard text.rangeOfCharacter(from: charset.inverted) == nil else { return false }
        // Padding only ever appears at the very end.
        if let eq = text.firstIndex(of: "="), text[eq...].contains(where: { $0 != "=" }) { return false }
        return Data(base64Encoded: text) != nil
    }
}
