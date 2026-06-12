import Foundation

public struct CurlImportedRequest: Sendable {
    public var method: String
    public var url: String
    public var headers: [KeyValuePair]
    public var body: CurlImportedBody?
    public var auth: AuthType?
    public var warnings: [String]
}

public enum CurlImportedBody: Sendable {
    case data(String)
    case multipart([MultipartPart])
}

/// Parses pasted cURL command lines (including Chrome's "Copy as cURL" output)
/// into request components. Pure logic, no UI.
public enum CurlImporter {
    /// Parse every curl command found in the text (commands may be separated
    /// by newlines, `;` or `&&`). Non-curl commands are skipped.
    public static func parse(_ text: String) -> [CurlImportedRequest] {
        splitCommands(text)
            .filter { $0.first?.lowercased() == "curl" }
            .compactMap { parseCommand($0) }
    }

    public static func parseFirst(_ text: String) -> CurlImportedRequest? {
        parse(text).first
    }

    // MARK: - Command parsing

    private static let booleanShortFlags: Set<Character> = ["s", "S", "L", "k", "v", "i", "f", "g", "#", "4", "6", "G", "I", "N"]
    private static let valueShortFlags: Set<Character> = ["X", "H", "d", "F", "u", "b", "A", "e", "o", "w", "m", "x", "T", "U", "K", "E", "c", "r", "z", "Q", "t", "C", "P", "y", "Y"]

    private static let booleanLongFlags: Set<String> = [
        "compressed", "insecure", "silent", "verbose", "location", "fail", "show-error",
        "include", "globoff", "progress-bar", "no-buffer", "disable", "ipv4", "ipv6",
        "http0.9", "http1.0", "http1.1", "http2", "http2-prior-knowledge", "http3",
        "tlsv1", "tlsv1.0", "tlsv1.1", "tlsv1.2", "tlsv1.3", "sslv2", "sslv3",
        "anyauth", "ntlm", "negotiate", "location-trusted", "fail-with-body", "no-progress-meter",
    ]
    private static let ignoredValueLongFlags: Set<String> = [
        "output", "proxy", "max-time", "connect-timeout", "retry", "retry-delay", "retry-max-time",
        "write-out", "cacert", "cert", "key", "capath", "cookie-jar", "upload-file", "max-redirs",
        "resolve", "range", "limit-rate", "interface", "dns-servers", "proxy-user", "ciphers",
        "trace", "trace-ascii", "dump-header", "config", "keepalive-time", "expect100-timeout",
        "unix-socket", "abstract-unix-socket", "aws-sigv4", "proxy-header", "url-query",
        "connect-to", "max-filesize", "doh-url", "pinnedpubkey", "tls13-ciphers", "local-port",
        "speed-limit", "speed-time", "output-dir", "alt-svc", "cert-type", "key-type", "pass",
        "noproxy", "proto", "proto-default", "happy-eyeballs-timeout-ms", "variable",
    ]

    private static func parseCommand(_ tokens: [String]) -> CurlImportedRequest? {
        var warnings: [String] = []
        var explicitMethod: String?
        var url = ""
        var headers: [KeyValuePair] = []
        var dataParts: [String] = []
        var formParts: [MultipartPart] = []
        var credentials: String?
        var bearerToken: String?
        var isDigest = false
        var useGet = false
        var headOnly = false
        var isJSON = false

        var i = 1
        func nextValue(_ flag: String, inline: String?) -> String? {
            if let inline { return inline }
            if i + 1 < tokens.count { i += 1; return tokens[i] }
            warnings.append("Missing value for \(flag)")
            return nil
        }

        func appendHeader(_ raw: String) {
            if let colon = raw.firstIndex(of: ":") {
                let key = String(raw[raw.startIndex..<colon]).trimmingCharacters(in: .whitespaces)
                let value = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
                headers.append(KeyValuePair(key: key, value: value))
            } else if raw.hasSuffix(";") {
                headers.append(KeyValuePair(key: String(raw.dropLast()).trimmingCharacters(in: .whitespaces), value: ""))
            } else {
                warnings.append("Skipped malformed header: \(raw)")
            }
        }

        func appendFormPart(_ raw: String, literal: Bool) {
            guard let eq = raw.firstIndex(of: "=") else {
                warnings.append("Skipped malformed form field: \(raw)")
                return
            }
            let name = String(raw[raw.startIndex..<eq])
            let value = String(raw[raw.index(after: eq)...])
            if !literal, value.hasPrefix("@") {
                var segments = value.dropFirst().components(separatedBy: ";")
                let path = segments.removeFirst()
                var mimeType = ""
                var filename = (path as NSString).lastPathComponent
                for segment in segments {
                    let trimmed = segment.trimmingCharacters(in: .whitespaces)
                    if trimmed.lowercased().hasPrefix("type=") {
                        mimeType = String(trimmed.dropFirst("type=".count))
                    } else if trimmed.lowercased().hasPrefix("filename=") {
                        filename = String(trimmed.dropFirst("filename=".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    }
                }
                formParts.append(MultipartPart(name: name, kind: .file(path: path, filename: filename, mimeType: mimeType)))
            } else if !literal, value.hasPrefix("<") {
                warnings.append("Form field \(name) reads from a file; imported as empty text")
                formParts.append(MultipartPart(name: name, kind: .text("")))
            } else {
                formParts.append(MultipartPart(name: name, kind: .text(value)))
            }
        }

        func handle(_ flag: String, inline: String?) {
            switch flag {
            case "url":
                if let v = nextValue(flag, inline: inline) { url = v }
            case "X", "request":
                if let v = nextValue(flag, inline: inline) { explicitMethod = v.uppercased() }
            case "H", "header":
                if let v = nextValue(flag, inline: inline) { appendHeader(v) }
            case "A", "user-agent":
                if let v = nextValue(flag, inline: inline) { headers.append(KeyValuePair(key: "User-Agent", value: v)) }
            case "e", "referer":
                if let v = nextValue(flag, inline: inline) { headers.append(KeyValuePair(key: "Referer", value: v)) }
            case "b", "cookie":
                if let v = nextValue(flag, inline: inline) {
                    if v.contains("=") {
                        headers.append(KeyValuePair(key: "Cookie", value: v))
                    } else {
                        warnings.append("Cookie file '\(v)' not imported")
                    }
                }
            case "d", "data", "data-raw", "data-binary", "data-ascii":
                if let v = nextValue(flag, inline: inline) {
                    if flag != "data-raw", v.hasPrefix("@") {
                        warnings.append("Data file '\(v)' not imported")
                    } else {
                        dataParts.append(v)
                    }
                }
            case "data-urlencode", "data-urlencoded":
                if let v = nextValue(flag, inline: inline) {
                    if let eq = v.firstIndex(of: "="), eq != v.startIndex {
                        let name = String(v[v.startIndex..<eq])
                        let content = String(v[v.index(after: eq)...])
                        dataParts.append("\(name)=\(urlEncode(content))")
                    } else if v.hasPrefix("=") {
                        dataParts.append(urlEncode(String(v.dropFirst())))
                    } else {
                        dataParts.append(urlEncode(v))
                    }
                }
            case "json":
                if let v = nextValue(flag, inline: inline) {
                    dataParts.append(v)
                    isJSON = true
                }
            case "F", "form":
                if let v = nextValue(flag, inline: inline) { appendFormPart(v, literal: false) }
            case "form-string":
                if let v = nextValue(flag, inline: inline) { appendFormPart(v, literal: true) }
            case "u", "user":
                if let v = nextValue(flag, inline: inline) { credentials = v }
            case "oauth2-bearer":
                if let v = nextValue(flag, inline: inline) { bearerToken = v }
            case "digest":
                isDigest = true
            case "basic":
                isDigest = false
            case "G", "get":
                useGet = true
            case "I", "head":
                headOnly = true
            default:
                if booleanLongFlags.contains(flag) || booleanShortFlags.contains(where: { String($0) == flag }) {
                    break
                }
                if ignoredValueLongFlags.contains(flag) || valueShortFlags.contains(where: { String($0) == flag }) {
                    _ = nextValue(flag, inline: inline)
                    break
                }
                warnings.append("Ignored unknown option \(flag.count == 1 ? "-" : "--")\(flag)")
            }
        }

        while i < tokens.count {
            let token = tokens[i]
            if token.hasPrefix("--") {
                let stripped = String(token.dropFirst(2))
                if let eq = stripped.firstIndex(of: "=") {
                    handle(String(stripped[stripped.startIndex..<eq]), inline: String(stripped[stripped.index(after: eq)...]))
                } else {
                    handle(stripped, inline: nil)
                }
            } else if token.hasPrefix("-"), token.count > 1 {
                let flags = Array(token.dropFirst())
                var j = 0
                while j < flags.count {
                    let c = flags[j]
                    if valueShortFlags.contains(c) {
                        let remainder = String(flags[(j + 1)...])
                        handle(String(c), inline: remainder.isEmpty ? nil : remainder)
                        break
                    }
                    handle(String(c), inline: nil)
                    j += 1
                }
            } else if url.isEmpty {
                url = token
            } else if !looksLikeURL(url), looksLikeURL(token) {
                // An unknown value-taking option may have left its argument as a
                // positional token; prefer the token that actually looks like a URL.
                warnings.append("Ignored extra argument: \(url)")
                url = token
            } else {
                warnings.append("Ignored extra argument: \(token)")
            }
            i += 1
        }

        guard !url.isEmpty else { return nil }

        if useGet, !dataParts.isEmpty {
            let query = dataParts.joined(separator: "&")
            url += url.contains("?") ? "&\(query)" : "?\(query)"
            dataParts = []
        }

        let method: String
        if let explicitMethod {
            method = explicitMethod
        } else if headOnly {
            method = "HEAD"
        } else if !dataParts.isEmpty || !formParts.isEmpty {
            method = "POST"
        } else {
            method = "GET"
        }

        var body: CurlImportedBody?
        if !formParts.isEmpty {
            body = .multipart(formParts)
        } else if !dataParts.isEmpty {
            body = .data(dataParts.joined(separator: "&"))
        }

        func hasHeader(_ name: String) -> Bool {
            headers.contains { $0.key.caseInsensitiveCompare(name) == .orderedSame }
        }
        if isJSON {
            if !hasHeader("Content-Type") { headers.append(KeyValuePair(key: "Content-Type", value: "application/json")) }
            if !hasHeader("Accept") { headers.append(KeyValuePair(key: "Accept", value: "application/json")) }
        } else if case .data = body, !hasHeader("Content-Type") {
            headers.append(KeyValuePair(key: "Content-Type", value: "application/x-www-form-urlencoded"))
        }

        var auth: AuthType?
        if let credentials {
            if let colon = credentials.firstIndex(of: ":") {
                let username = String(credentials[credentials.startIndex..<colon])
                let password = String(credentials[credentials.index(after: colon)...])
                auth = isDigest ? .digestAuth(username: username, password: password) : .basicAuth(username: username, password: password)
            } else {
                auth = isDigest ? .digestAuth(username: credentials, password: "") : .basicAuth(username: credentials, password: "")
            }
        }
        if let bearerToken { auth = .bearerToken(bearerToken) }

        return CurlImportedRequest(method: method, url: url, headers: headers, body: body, auth: auth, warnings: warnings)
    }

    /// Heuristic used to pick the URL among positional arguments: explicit
    /// schemes always win, otherwise an http(s)-looking token does.
    private static func looksLikeURL(_ token: String) -> Bool {
        token.contains("://") || token.lowercased().hasPrefix("http")
    }

    private static func urlEncode(_ text: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return text.addingPercentEncoding(withAllowedCharacters: allowed) ?? text
    }

    // MARK: - Tokenizer

    /// Splits shell text into commands (groups of tokens), honoring single quotes,
    /// double quotes with backslash escapes, $'...' ANSI-C quoting, and
    /// backslash-newline continuations. `&&` and `;` always separate commands;
    /// a bare newline only separates when the next token starts a new `curl` command.
    static func splitCommands(_ input: String) -> [[String]] {
        var commands: [[String]] = []
        var tokens: [String] = []
        var current = ""
        var hasCurrent = false
        var softBreak = false
        let chars = Array(input)
        var i = 0

        func flushToken() {
            guard hasCurrent else { return }
            if softBreak {
                if current.lowercased() == "curl", !tokens.isEmpty {
                    commands.append(tokens)
                    tokens = []
                }
                softBreak = false
            }
            tokens.append(current)
            current = ""
            hasCurrent = false
        }
        func hardBreak() {
            flushToken()
            softBreak = false
            if !tokens.isEmpty {
                commands.append(tokens)
                tokens = []
            }
        }

        while i < chars.count {
            let c = chars[i]
            switch c {
            case "\\":
                if i + 1 < chars.count {
                    let n = chars[i + 1]
                    if n == "\n" { i += 2; continue }
                    if n == "\r", i + 2 < chars.count, chars[i + 2] == "\n" { i += 3; continue }
                    current.append(n)
                    hasCurrent = true
                    i += 2
                    continue
                }
                i += 1
            case "'":
                hasCurrent = true
                i += 1
                while i < chars.count, chars[i] != "'" {
                    current.append(chars[i])
                    i += 1
                }
                i += 1
            case "$" where i + 1 < chars.count && chars[i + 1] == "'":
                hasCurrent = true
                i += 2
                while i < chars.count, chars[i] != "'" {
                    if chars[i] == "\\", i + 1 < chars.count {
                        i += 1
                        appendAnsiCEscape(chars, &i, into: &current)
                    } else {
                        current.append(chars[i])
                        i += 1
                    }
                }
                i += 1
            case "\"":
                hasCurrent = true
                i += 1
                while i < chars.count, chars[i] != "\"" {
                    if chars[i] == "\\", i + 1 < chars.count {
                        let n = chars[i + 1]
                        if n == "\"" || n == "\\" || n == "$" || n == "`" {
                            current.append(n)
                            i += 2
                        } else if n == "\n" {
                            i += 2
                        } else {
                            current.append("\\")
                            i += 1
                        }
                    } else {
                        current.append(chars[i])
                        i += 1
                    }
                }
                i += 1
            case "&" where i + 1 < chars.count && chars[i + 1] == "&":
                hardBreak()
                i += 2
            case ";":
                hardBreak()
                i += 1
            case "\n", "\r":
                flushToken()
                softBreak = true
                i += 1
            case " ", "\t":
                flushToken()
                i += 1
            default:
                current.append(c)
                hasCurrent = true
                i += 1
            }
        }
        flushToken()
        if !tokens.isEmpty { commands.append(tokens) }
        return commands
    }

    private static func appendAnsiCEscape(_ chars: [Character], _ i: inout Int, into current: inout String) {
        guard i < chars.count else { return }
        let e = chars[i]
        i += 1
        switch e {
        case "n": current.append("\n")
        case "t": current.append("\t")
        case "r": current.append("\r")
        case "a": current.append("\u{07}")
        case "b": current.append("\u{08}")
        case "f": current.append("\u{0C}")
        case "v": current.append("\u{0B}")
        case "e", "E": current.append("\u{1B}")
        case "\\": current.append("\\")
        case "'": current.append("'")
        case "\"": current.append("\"")
        case "0", "1", "2", "3", "4", "5", "6", "7":
            var digits = String(e)
            while digits.count < 3, i < chars.count, ("0"..."7").contains(String(chars[i])) {
                digits.append(chars[i])
                i += 1
            }
            if let value = UInt32(digits, radix: 8), let scalar = Unicode.Scalar(value) {
                current.append(Character(scalar))
            }
        case "x":
            var digits = ""
            while digits.count < 2, i < chars.count, chars[i].isHexDigit {
                digits.append(chars[i])
                i += 1
            }
            if let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) {
                current.append(Character(scalar))
            }
        case "u", "U":
            let width = e == "u" ? 4 : 8
            var digits = ""
            while digits.count < width, i < chars.count, chars[i].isHexDigit {
                digits.append(chars[i])
                i += 1
            }
            if let value = UInt32(digits, radix: 16), let scalar = Unicode.Scalar(value) {
                current.append(Character(scalar))
            }
        default:
            current.append("\\")
            current.append(e)
        }
    }
}
