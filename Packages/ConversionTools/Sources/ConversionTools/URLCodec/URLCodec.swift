import Foundation

public enum URLEncodingStandard: String, CaseIterable, Identifiable, Sendable {
    case rfc3986 = "RFC 3986"
    case formData = "Form Data"
    public var id: String { rawValue }
}

public enum URLCodec {
    public static func encode(_ string: String, standard: URLEncodingStandard = .rfc3986) -> String {
        switch standard {
        case .rfc3986:
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "!*'();:@&=+$,/?#[]% ")
            return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        case .formData:
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
            return encoded.replacingOccurrences(of: "%20", with: "+")
        }
    }

    public static func decode(_ string: String) -> String {
        string.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? string
    }

    public static func parse(_ urlString: String) -> URLComponents? {
        guard !urlString.isEmpty else { return nil }
        return URLComponents(string: urlString)
    }
}
