import Foundation

public enum HTMLEntityCodec {
    private static let encodeMap: [(String, String)] = [("&", "&amp;"), ("<", "&lt;"), (">", "&gt;"), ("\"", "&quot;"), ("'", "&#39;")]

    public static func encode(_ input: String) -> String {
        var result = input; for (char, entity) in encodeMap { result = result.replacingOccurrences(of: char, with: entity) }; return result
    }

    public static func decode(_ input: String) -> String {
        var result = input
        for (char, entity) in encodeMap.reversed() { result = result.replacingOccurrences(of: entity, with: char) }
        // Numeric entities &#123;
        let decimalPattern = /&#(\d+);/
        result = result.replacing(decimalPattern) { match in
            if let code = UInt32(match.1), let scalar = Unicode.Scalar(code) { return String(Character(scalar)) }; return String(match.0)
        }
        let hexPattern = /&#x([0-9a-fA-F]+);/
        result = result.replacing(hexPattern) { match in
            if let code = UInt32(match.1, radix: 16), let scalar = Unicode.Scalar(code) { return String(Character(scalar)) }; return String(match.0)
        }
        return result
    }
}
