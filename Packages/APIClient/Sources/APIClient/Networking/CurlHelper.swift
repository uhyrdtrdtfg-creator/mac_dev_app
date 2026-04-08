import Foundation

public enum CurlHelper {
    /// Export a URLRequest as a cURL command string
    public static func export(_ request: URLRequest) -> String {
        var parts = ["curl"]

        if let method = request.httpMethod, method != "GET" {
            parts.append("-X \(method)")
        }

        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers.sorted(by: { $0.key < $1.key }) {
                parts.append("-H '\(key): \(value)'")
            }
        }

        if let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            let escaped = bodyString.replacingOccurrences(of: "'", with: "'\\''")
            parts.append("-d '\(escaped)'")
        }

        if let url = request.url?.absoluteString {
            parts.append("'\(url)'")
        }

        return parts.joined(separator: " \\\n  ")
    }

    /// Parse a cURL command string into components
    public static func parse(_ curl: String) -> CurlParseResult? {
        let trimmed = curl.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("curl") else { return nil }

        // Normalize line continuations
        let normalized = trimmed.replacingOccurrences(of: "\\\n", with: " ").replacingOccurrences(of: "\\\r\n", with: " ")

        var method = "GET"
        var url = ""
        var headers: [(String, String)] = []
        var body: String?

        let tokens = tokenize(normalized)
        var i = 0
        while i < tokens.count {
            let token = tokens[i]
            switch token {
            case "curl":
                break
            case "-X", "--request":
                if i + 1 < tokens.count { method = tokens[i + 1].uppercased(); i += 1 }
            case "-H", "--header":
                if i + 1 < tokens.count {
                    let header = tokens[i + 1]
                    if let colonIndex = header.firstIndex(of: ":") {
                        let key = String(header[header.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(header[header.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        headers.append((key, value))
                    }
                    i += 1
                }
            case "-d", "--data", "--data-raw", "--data-binary":
                if i + 1 < tokens.count {
                    body = tokens[i + 1]
                    if method == "GET" { method = "POST" }
                    i += 1
                }
            default:
                if !token.hasPrefix("-") && url.isEmpty {
                    url = token
                }
            }
            i += 1
        }

        guard !url.isEmpty else { return nil }
        return CurlParseResult(method: method, url: url, headers: headers, body: body)
    }

    private static func tokenize(_ input: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var escapeNext = false

        for char in input {
            if escapeNext {
                current.append(char)
                escapeNext = false
                continue
            }
            if char == "\\" && !inSingleQuote {
                escapeNext = true
                continue
            }
            if char == "'" && !inDoubleQuote {
                inSingleQuote.toggle()
                continue
            }
            if char == "\"" && !inSingleQuote {
                inDoubleQuote.toggle()
                continue
            }
            if char.isWhitespace && !inSingleQuote && !inDoubleQuote {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                continue
            }
            current.append(char)
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}

public struct CurlParseResult: Sendable {
    public let method: String
    public let url: String
    public let headers: [(String, String)]
    public let body: String?
}
