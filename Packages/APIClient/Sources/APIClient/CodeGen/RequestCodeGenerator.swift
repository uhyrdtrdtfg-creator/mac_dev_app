import Foundation

public enum CodeGenLanguage: String, CaseIterable, Identifiable, Sendable {
    case swiftURLSession = "Swift"
    case pythonRequests = "Python"
    case jsFetch = "JS fetch"
    case nodeAxios = "axios"
    case goNetHTTP = "Go"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .swiftURLSession: "Swift (URLSession)"
        case .pythonRequests: "Python (requests)"
        case .jsFetch: "JavaScript (fetch)"
        case .nodeAxios: "Node.js (axios)"
        case .goNetHTTP: "Go (net/http)"
        }
    }
}

public struct CodeGenRequest: Sendable {
    public var method: HTTPMethod
    public var url: String
    public var headers: [KeyValuePair]
    public var queryParams: [KeyValuePair]
    public var body: RequestBody?
    public var auth: AuthType?

    public init(method: HTTPMethod, url: String, headers: [KeyValuePair] = [], queryParams: [KeyValuePair] = [], body: RequestBody? = nil, auth: AuthType? = nil) {
        self.method = method; self.url = url; self.headers = headers
        self.queryParams = queryParams; self.body = body; self.auth = auth
    }

    public init(curl: CurlParseResult) {
        let body: RequestBody? = curl.body.map { text in
            if let data = text.data(using: .utf8), (try? JSONSerialization.jsonObject(with: data)) != nil {
                return .json(text)
            }
            return .raw(text)
        }
        self.init(
            method: HTTPMethod(rawValue: curl.method) ?? .get,
            url: curl.url,
            headers: curl.headers.map { KeyValuePair(key: $0.0, value: $0.1) },
            body: body
        )
    }
}

public enum RequestCodeGenerator {

    // Normalized view of the request, mirroring HTTPClientService.buildURLRequest:
    // query params merged into the URL, auth and Content-Type resolved into headers
    // (except where a language has a more idiomatic auth form).
    private struct Plan {
        var method: String
        var url: String
        var headers: [(String, String)]   // ordered, auth/content-type appended last
        var jsonBody: String?
        var formPairs: [(String, String)]?
        var rawBody: String?
        var binaryByteCount: Int?
        var placeholderComment: String?
        var basicAuth: (user: String, password: String)?

        var hasBody: Bool { jsonBody != nil || formPairs != nil || rawBody != nil }
    }

    private static func plan(for request: CodeGenRequest, nativeBasicAuth: Bool) -> Plan {
        var queryItems = request.queryParams
            .filter { $0.isEnabled && !$0.key.isEmpty }
            .map { URLQueryItem(name: $0.key, value: $0.value) }
        if case .apiKey(let key, let value, .queryParam) = request.auth {
            queryItems.append(URLQueryItem(name: key, value: value))
        }
        var url = request.url
        if !queryItems.isEmpty {
            if var components = URLComponents(string: request.url) {
                components.queryItems = (components.queryItems ?? []) + queryItems
                url = components.url?.absoluteString ?? request.url
            } else {
                let raw = queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")
                url = request.url + (request.url.contains("?") ? "&" : "?") + raw
            }
        }

        var headers: [(String, String)] = request.headers
            .filter { $0.isEnabled && !$0.key.isEmpty }
            .map { ($0.key, $0.value) }
        let hasContentType = headers.contains { $0.0.caseInsensitiveCompare("Content-Type") == .orderedSame }

        var plan = Plan(method: request.method.rawValue, url: url, headers: headers)
        switch request.body {
        case .json(let json):
            plan.jsonBody = json
            if !hasContentType { headers.append(("Content-Type", "application/json")) }
        case .formData(let pairs):
            plan.formPairs = pairs.filter(\.isEnabled).map { ($0.key, $0.value) }
            if !hasContentType { headers.append(("Content-Type", "application/x-www-form-urlencoded")) }
        case .raw(let text):
            plan.rawBody = text
        case .binary(let data):
            plan.binaryByteCount = data.count
        case .graphql(let query, let variables):
            if let envelope = try? GraphQLEnvelope.buildString(query: query, variables: variables) {
                plan.jsonBody = envelope
                if !hasContentType { headers.append(("Content-Type", "application/json")) }
            } else {
                plan.placeholderComment = "GraphQL body omitted — variables are not valid JSON"
            }
        case nil:
            break
        }

        switch request.auth {
        case .bearerToken(let token):
            headers.append(("Authorization", "Bearer \(token)"))
        case .basicAuth(let user, let password):
            if nativeBasicAuth {
                plan.basicAuth = (user, password)
            } else {
                let credentials = Data("\(user):\(password)".utf8).base64EncodedString()
                headers.append(("Authorization", "Basic \(credentials)"))
            }
        case .apiKey(let key, let value, .header):
            headers.append((key, value))
        case .apiKey(_, _, .queryParam), nil:
            break
        }
        plan.headers = headers
        return plan
    }

    public static func generate(_ language: CodeGenLanguage, request: CodeGenRequest) -> String {
        switch language {
        case .swiftURLSession: swiftURLSession(request)
        case .pythonRequests: pythonRequests(request)
        case .jsFetch: jsFetch(request)
        case .nodeAxios: nodeAxios(request)
        case .goNetHTTP: goNetHTTP(request)
        }
    }

    // MARK: - Swift (URLSession)

    private static func swiftURLSession(_ request: CodeGenRequest) -> String {
        let plan = plan(for: request, nativeBasicAuth: false)
        var lines = ["import Foundation", ""]
        lines.append("var request = URLRequest(url: URL(string: \(swiftString(plan.url)))!)")
        lines.append("request.httpMethod = \(swiftString(plan.method))")
        for (key, value) in plan.headers {
            lines.append("request.setValue(\(swiftString(value)), forHTTPHeaderField: \(swiftString(key)))")
        }
        if let json = plan.jsonBody {
            lines.append("let body = \(swiftBodyLiteral(json))")
            lines.append("request.httpBody = Data(body.utf8)")
        } else if let pairs = plan.formPairs {
            lines.append("let body = \(swiftString(formEncoded(pairs)))")
            lines.append("request.httpBody = Data(body.utf8)")
        } else if let raw = plan.rawBody {
            lines.append("let body = \(swiftBodyLiteral(raw))")
            lines.append("request.httpBody = Data(body.utf8)")
        } else if let count = plan.binaryByteCount {
            lines.append("// Binary body (\(count) bytes) — load it from a file:")
            lines.append("request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \"/path/to/body\"))")
        } else if let comment = plan.placeholderComment {
            lines.append("// \(comment)")
        }
        lines.append("")
        lines.append("let (data, response) = try await URLSession.shared.data(for: request)")
        lines.append("print((response as? HTTPURLResponse)?.statusCode ?? 0)")
        lines.append("print(String(decoding: data, as: UTF8.self))")
        return lines.joined(separator: "\n")
    }

    // MARK: - Python (requests)

    private static func pythonRequests(_ request: CodeGenRequest) -> String {
        let plan = plan(for: request, nativeBasicAuth: true)
        var lines = ["import requests"]
        let jsonPayload = plan.jsonBody.flatMap(validJSON)
        if jsonPayload != nil { lines.insert("import json", at: 0) }
        lines.append("")
        lines.append("url = \(pythonString(plan.url))")

        var callArgs = ["url"]
        if !plan.headers.isEmpty {
            lines.append("headers = {")
            for (key, value) in plan.headers { lines.append("    \(pythonString(key)): \(pythonString(value)),") }
            lines.append("}")
            callArgs.append("headers=headers")
        }
        if let json = jsonPayload {
            lines.append("# requests re-serializes this JSON (key order/whitespace/escapes may differ);")
            lines.append("# pass data=<raw string> instead if byte-identical bodies matter.")
            lines.append("payload = json.loads(\(pythonBodyLiteral(json)))")
            callArgs.append("json=payload")
        } else if let json = plan.jsonBody {
            lines.append("data = \(pythonBodyLiteral(json))")
            callArgs.append("data=data")
        } else if let pairs = plan.formPairs {
            lines.append("data = \(pythonString(formEncoded(pairs)))")
            callArgs.append("data=data")
        } else if let raw = plan.rawBody {
            lines.append("data = \(pythonBodyLiteral(raw))")
            callArgs.append("data=data")
        } else if let count = plan.binaryByteCount {
            lines.append("# Binary body (\(count) bytes) — load it from a file:")
            lines.append("data = open(\"/path/to/body\", \"rb\").read()")
            callArgs.append("data=data")
        } else if let comment = plan.placeholderComment {
            lines.append("# \(comment)")
        }
        if let basic = plan.basicAuth {
            callArgs.append("auth=(\(pythonString(basic.user)), \(pythonString(basic.password)))")
        }
        lines.append("")
        lines.append("response = requests.request(\(pythonString(plan.method)), \(callArgs.joined(separator: ", ")))")
        lines.append("print(response.status_code)")
        lines.append("print(response.text)")
        return lines.joined(separator: "\n")
    }

    // MARK: - JavaScript (fetch)

    private static func jsFetch(_ request: CodeGenRequest) -> String {
        let plan = plan(for: request, nativeBasicAuth: false)
        // Top-level await only parses as a module, so wrap in an async IIFE.
        // Multi-line body literals are appended verbatim — never re-indent them.
        var lines = ["(async () => {"]
        lines.append("  const response = await fetch(\(jsString(plan.url)), {")
        lines.append("    method: \(jsString(plan.method)),")
        if !plan.headers.isEmpty {
            lines.append("    headers: {")
            for (key, value) in plan.headers { lines.append("      \(jsString(key)): \(jsString(value)),") }
            lines.append("    },")
        }
        if let body = plan.jsonBody ?? plan.rawBody {
            lines.append("    body: \(jsBodyLiteral(body)),")
        } else if let pairs = plan.formPairs {
            lines.append("    body: \(jsString(formEncoded(pairs))),")
        } else if let count = plan.binaryByteCount {
            lines.append("    // Binary body (\(count) bytes) — pass a Blob/Buffer here.")
        } else if let comment = plan.placeholderComment {
            lines.append("    // \(comment)")
        }
        lines.append("  });")
        lines.append("  console.log(response.status);")
        lines.append("  console.log(await response.text());")
        lines.append("})();")
        return lines.joined(separator: "\n")
    }

    // MARK: - Node.js (axios)

    private static func nodeAxios(_ request: CodeGenRequest) -> String {
        let plan = plan(for: request, nativeBasicAuth: true)
        var lines = ["const axios = require(\"axios\");", ""]
        var options = [
            "    method: \(jsString(plan.method.lowercased())),",
            "    url: \(jsString(plan.url)),",
        ]
        if !plan.headers.isEmpty {
            var headerLines = ["    headers: {"]
            for (key, value) in plan.headers { headerLines.append("      \(jsString(key)): \(jsString(value)),") }
            headerLines.append("    },")
            options.append(headerLines.joined(separator: "\n"))
        }
        if let body = plan.jsonBody ?? plan.rawBody {
            options.append("    data: \(jsBodyLiteral(body)),")
        } else if let pairs = plan.formPairs {
            options.append("    data: \(jsString(formEncoded(pairs))),")
        } else if let count = plan.binaryByteCount {
            options.append("    // Binary body (\(count) bytes) — pass a Buffer here.")
        } else if let comment = plan.placeholderComment {
            options.append("    // \(comment)")
        }
        if let basic = plan.basicAuth {
            options.append("    auth: { username: \(jsString(basic.user)), password: \(jsString(basic.password)) },")
        }
        lines.append("async function main() {")
        lines.append("  const response = await axios({")
        lines.append(options.joined(separator: "\n"))
        lines.append("  });")
        lines.append("  console.log(response.status);")
        lines.append("  console.log(response.data);")
        lines.append("}")
        lines.append("")
        lines.append("main().catch((err) => console.error(err.message));")
        return lines.joined(separator: "\n")
    }

    // MARK: - Go (net/http)

    private static func goNetHTTP(_ request: CodeGenRequest) -> String {
        let plan = plan(for: request, nativeBasicAuth: true)
        var bodyDecl: String?
        var bodyArg = "nil"
        if let json = plan.jsonBody {
            bodyDecl = "body := strings.NewReader(\(goBodyString(json)))"
        } else if let pairs = plan.formPairs {
            bodyDecl = "body := strings.NewReader(\(goBodyString(formEncoded(pairs))))"
        } else if let raw = plan.rawBody {
            bodyDecl = "body := strings.NewReader(\(goBodyString(raw)))"
        } else if let count = plan.binaryByteCount {
            bodyDecl = "// Binary body (\(count) bytes) — open a file instead:\n\tbody, _ := os.Open(\"/path/to/body\")"
        }
        if bodyDecl != nil { bodyArg = "body" }

        var imports = ["\"fmt\"", "\"io\"", "\"net/http\""]
        if plan.jsonBody != nil || plan.formPairs != nil || plan.rawBody != nil { imports.append("\"strings\"") }
        if plan.binaryByteCount != nil { imports.append("\"os\"") }

        var lines = ["package main", "", "import ("]
        for imp in imports.sorted() { lines.append("\t\(imp)") }
        lines.append(")")
        lines.append("")
        lines.append("func main() {")
        if let bodyDecl { lines.append("\t\(bodyDecl)") }
        else if let comment = plan.placeholderComment { lines.append("\t// \(comment)") }
        lines.append("\treq, err := http.NewRequest(\(goString(plan.method)), \(goString(plan.url)), \(bodyArg))")
        lines.append("\tif err != nil {")
        lines.append("\t\tpanic(err)")
        lines.append("\t}")
        for (key, value) in plan.headers {
            lines.append("\treq.Header.Set(\(goString(key)), \(goString(value)))")
        }
        if let basic = plan.basicAuth {
            lines.append("\treq.SetBasicAuth(\(goString(basic.user)), \(goString(basic.password)))")
        }
        lines.append("")
        lines.append("\tresp, err := http.DefaultClient.Do(req)")
        lines.append("\tif err != nil {")
        lines.append("\t\tpanic(err)")
        lines.append("\t}")
        lines.append("\tdefer resp.Body.Close()")
        lines.append("")
        lines.append("\tdata, err := io.ReadAll(resp.Body)")
        lines.append("\tif err != nil {")
        lines.append("\t\tpanic(err)")
        lines.append("\t}")
        lines.append("\tfmt.Println(resp.Status)")
        lines.append("\tfmt.Println(string(data))")
        lines.append("}")
        return lines.joined(separator: "\n")
    }

    // MARK: - Escaping helpers

    private static func validJSON(_ text: String) -> String? {
        guard let data = text.data(using: .utf8),
              (try? JSONSerialization.jsonObject(with: data)) != nil else { return nil }
        return text
    }

    private static func formEncoded(_ pairs: [(String, String)]) -> String {
        // Mirrors HTTPClientService.buildURLRequest's form encoding (no percent-escaping).
        pairs.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
    }

    /// Escapes at the unicode-scalar level: grapheme-cluster iteration would treat
    /// CRLF as a single Character and let raw CR/LF bytes leak into the literal.
    private static func escapeCommon(_ text: String, quote: Unicode.Scalar) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case quote: out += "\\\(quote)"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out
    }

    private static func containsCR(_ text: String) -> Bool {
        text.unicodeScalars.contains("\r")
    }

    private static func swiftString(_ text: String) -> String { "\"\(escapeCommon(text, quote: "\""))\"" }
    private static func goString(_ text: String) -> String { "\"\(escapeCommon(text, quote: "\""))\"" }
    private static func pythonString(_ text: String) -> String { "'\(escapeCommon(text, quote: "'"))'" }

    private static func jsString(_ text: String) -> String {
        var escaped = escapeCommon(text, quote: "\"")
        escaped = escaped.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "\"\(escaped)\""
    }

    // Body literals: multiline forms read best, but every target language silently
    // normalizes raw CR/CRLF inside them — fall back to a single-line escaped
    // literal whenever the body contains CR so the sent bytes match the app's.

    /// Multiline Swift raw string with enough `#` delimiters to contain the text verbatim.
    private static func swiftBodyLiteral(_ text: String) -> String {
        if containsCR(text) { return swiftString(text) }
        var hashes = "#"
        while text.contains("\"\"\"\(hashes)") || text.contains("\\\(hashes)") { hashes += "#" }
        return "\(hashes)\"\"\"\n\(text)\n\"\"\"\(hashes)"
    }

    /// Python triple-quoted string; escapes backslashes and double quotes so the
    /// content can never terminate the literal early.
    private static func pythonBodyLiteral(_ text: String) -> String {
        if containsCR(text) { return pythonString(text) }
        let escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\"\"\(escaped)\"\"\""
    }

    /// JS template literal escaping backticks and interpolation.
    private static func jsBodyLiteral(_ text: String) -> String {
        if containsCR(text) { return jsString(text) }
        var escaped = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "${", with: "\\${")
        escaped = escaped.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
        escaped = escaped.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
        return "`\(escaped)`"
    }

    /// Go body literal: backtick raw string when possible (raw literals drop CR),
    /// interpreted string otherwise.
    private static func goBodyString(_ text: String) -> String {
        if !text.unicodeScalars.contains("`") && !containsCR(text) { return "`\(text)`" }
        return goString(text)
    }
}
