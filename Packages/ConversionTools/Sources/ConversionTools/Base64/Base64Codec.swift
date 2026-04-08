import Foundation

public enum Base64Codec {
    public static func encode(_ string: String, urlSafe: Bool = false) -> String {
        encodeData(Data(string.utf8), urlSafe: urlSafe)
    }

    public static func encodeData(_ data: Data, urlSafe: Bool = false) -> String {
        var result = data.base64EncodedString()
        if urlSafe {
            result = result.replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        }
        return result
    }

    public static func decode(_ base64: String, urlSafe: Bool = false) -> String? {
        guard let data = decodeToData(base64, urlSafe: urlSafe) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decodeToData(_ base64: String, urlSafe: Bool = false) -> Data? {
        var input = base64
        if urlSafe {
            input = input.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
            let remainder = input.count % 4
            if remainder > 0 { input += String(repeating: "=", count: 4 - remainder) }
        }
        return Data(base64Encoded: input)
    }
}
