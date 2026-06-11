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
    /// Source path of a `.binary` body, when known — lets generators emit a real read-file idiom.
    public var binaryFilePath: String?

    public init(method: HTTPMethod, url: String, headers: [KeyValuePair] = [], queryParams: [KeyValuePair] = [], body: RequestBody? = nil, auth: AuthType? = nil, binaryFilePath: String? = nil) {
        self.method = method; self.url = url; self.headers = headers
        self.queryParams = queryParams; self.body = body; self.auth = auth
        self.binaryFilePath = binaryFilePath
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
            body: body,
            auth: curl.auth
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
        var binaryFilePath: String?
        var multipartParts: [MultipartPart]?
        var placeholderComment: String?
        var basicAuth: (user: String, password: String)?
        var digestAuth: (user: String, password: String)?

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
            plan.binaryFilePath = request.binaryFilePath
        case .multipart(let parts):
            // No Content-Type here — each language's multipart API sets its own boundary.
            plan.multipartParts = parts.filter { $0.isEnabled }
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
        case .digestAuth(let user, let password):
            plan.digestAuth = (user, password)
        case .apiKey(let key, let value, .header):
            headers.append((key, value))
        case .oauth2(let config):
            headers.append(("Authorization", "Bearer \(config.tokens?.accessToken ?? "ACCESS_TOKEN")"))
        case .apiKey(_, _, .queryParam), nil:
            break
        }
        plan.headers = headers
        return plan
    }

    private static func textParts(_ parts: [MultipartPart]) -> [(name: String, value: String)] {
        parts.compactMap { part in
            if case .text(let value) = part.kind { return (part.name, value) }
            return nil
        }
    }

    private static func fileParts(_ parts: [MultipartPart]) -> [(name: String, path: String, filename: String, mime: String)] {
        parts.compactMap { part in
            if case .file(let path, let filename, let mime) = part.kind {
                return (part.name, path,
                        filename.isEmpty ? (path as NSString).lastPathComponent : filename,
                        mime.isEmpty ? "application/octet-stream" : mime)
            }
            return nil
        }
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
        } else if let parts = plan.multipartParts {
            lines.append(#"let boundary = "Boundary-\(UUID().uuidString)""#)
            lines.append(#"request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")"#)
            lines.append("var body = Data()")
            for part in parts {
                let name = escapeCommon(MultipartEncoder.escapeDispositionValue(part.name), quote: "\"")
                switch part.kind {
                case .text(let value):
                    let escaped = escapeCommon(value, quote: "\"")
                    lines.append(#"body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\#(name)\"\r\n\r\n\#(escaped)\r\n".utf8))"#)
                case .file(let path, let filename, let mime):
                    let resolvedFilename = escapeCommon(MultipartEncoder.escapeDispositionValue(filename.isEmpty ? (path as NSString).lastPathComponent : filename), quote: "\"")
                    let resolvedMime = escapeCommon(mime.isEmpty ? "application/octet-stream" : mime, quote: "\"")
                    lines.append(#"body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\#(name)\"; filename=\"\#(resolvedFilename)\"\r\nContent-Type: \#(resolvedMime)\r\n\r\n".utf8))"#)
                    lines.append("body.append(try Data(contentsOf: URL(fileURLWithPath: \(swiftString(path)))))")
                    lines.append(#"body.append(Data("\r\n".utf8))"#)
                }
            }
            lines.append(#"body.append(Data("--\(boundary)--\r\n".utf8))"#)
            lines.append("request.httpBody = body")
        } else if let count = plan.binaryByteCount {
            if let path = plan.binaryFilePath {
                lines.append("// Binary body (\(count) bytes) read from file:")
                lines.append("request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \(swiftString(path))))")
            } else {
                lines.append("// Binary body (\(count) bytes) — load it from a file:")
                lines.append("request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \"/path/to/body\"))")
            }
        } else if let comment = plan.placeholderComment {
            lines.append("// \(comment)")
        }
        if let digest = plan.digestAuth {
            lines.append("// Digest auth (user: \(digest.user)) — answer the challenge from a URLSessionTaskDelegate with")
            lines.append("// URLCredential(user:password:persistence:.forSession) for NSURLAuthenticationMethodHTTPDigest.")
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
        if plan.digestAuth != nil { lines.append("from requests.auth import HTTPDigestAuth") }
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
        } else if let parts = plan.multipartParts {
            let texts = textParts(parts)
            let files = fileParts(parts)
            if !texts.isEmpty {
                lines.append("data = {")
                for (name, value) in texts { lines.append("    \(pythonString(name)): \(pythonString(value)),") }
                lines.append("}")
                callArgs.append("data=data")
            }
            if !files.isEmpty {
                lines.append("files = {")
                for file in files {
                    lines.append("    \(pythonString(file.name)): (\(pythonString(file.filename)), open(\(pythonString(file.path)), 'rb'), \(pythonString(file.mime))),")
                }
                lines.append("}")
                callArgs.append("files=files")
            } else {
                lines.append("# No file parts — requests only sends multipart/form-data when files= is present;")
                lines.append("# use files={'name': (None, 'value')} to force a multipart body.")
            }
        } else if let count = plan.binaryByteCount {
            if let path = plan.binaryFilePath {
                lines.append("# Binary body (\(count) bytes) read from file:")
                lines.append("data = open(\(pythonString(path)), \"rb\").read()")
            } else {
                lines.append("# Binary body (\(count) bytes) — load it from a file:")
                lines.append("data = open(\"/path/to/body\", \"rb\").read()")
            }
            callArgs.append("data=data")
        } else if let comment = plan.placeholderComment {
            lines.append("# \(comment)")
        }
        if let basic = plan.basicAuth {
            callArgs.append("auth=(\(pythonString(basic.user)), \(pythonString(basic.password)))")
        }
        if let digest = plan.digestAuth {
            callArgs.append("auth=HTTPDigestAuth(\(pythonString(digest.user)), \(pythonString(digest.password)))")
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
        var lines: [String] = []
        if plan.binaryFilePath != nil {
            lines.append("const { readFileSync } = require(\"node:fs\");")
            lines.append("")
        }
        lines.append("(async () => {")
        if let digest = plan.digestAuth {
            lines.append("  // Digest auth (user: \(digest.user)) — fetch has no built-in support; use a library like digest-fetch.")
        }
        if let parts = plan.multipartParts {
            lines.append("  // Content-Type with the multipart boundary is set automatically.")
            lines.append("  const form = new FormData();")
            for part in parts {
                switch part.kind {
                case .text(let value):
                    lines.append("  form.append(\(jsString(part.name)), \(jsString(value)));")
                case .file(let path, let filename, let mime):
                    let resolvedFilename = filename.isEmpty ? (path as NSString).lastPathComponent : filename
                    let resolvedMime = mime.isEmpty ? "application/octet-stream" : mime
                    lines.append("  // File part \(jsString(part.name)) — replace the placeholder with the contents of \(jsString(path)):")
                    lines.append("  form.append(\(jsString(part.name)), new File([\(jsString("/* file bytes */"))], \(jsString(resolvedFilename)), { type: \(jsString(resolvedMime)) }));")
                }
            }
            lines.append("")
        }
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
        } else if plan.multipartParts != nil {
            lines.append("    body: form,")
        } else if let count = plan.binaryByteCount {
            if let path = plan.binaryFilePath {
                lines.append("    body: readFileSync(\(jsString(path))), // \(count) bytes")
            } else {
                lines.append("    // Binary body (\(count) bytes) — pass a Blob/Buffer here.")
            }
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
        var lines = ["const axios = require(\"axios\");"]
        if let parts = plan.multipartParts {
            lines.append("const FormData = require(\"form-data\");")
            if !fileParts(parts).isEmpty { lines.append("const fs = require(\"fs\");") }
        } else if plan.binaryFilePath != nil {
            lines.append("const fs = require(\"fs\");")
        }
        lines.append("")
        if let parts = plan.multipartParts {
            lines.append("const form = new FormData();")
            for part in parts {
                switch part.kind {
                case .text(let value):
                    lines.append("form.append(\(jsString(part.name)), \(jsString(value)));")
                case .file(let path, let filename, let mime):
                    let resolvedFilename = filename.isEmpty ? (path as NSString).lastPathComponent : filename
                    let resolvedMime = mime.isEmpty ? "application/octet-stream" : mime
                    lines.append("form.append(\(jsString(part.name)), fs.createReadStream(\(jsString(path))), { filename: \(jsString(resolvedFilename)), contentType: \(jsString(resolvedMime)) });")
                }
            }
            lines.append("")
        }
        var options = [
            "    method: \(jsString(plan.method.lowercased())),",
            "    url: \(jsString(plan.url)),",
        ]
        if !plan.headers.isEmpty || plan.multipartParts != nil {
            var headerLines = ["    headers: {"]
            if plan.multipartParts != nil { headerLines.append("      ...form.getHeaders(),") }
            for (key, value) in plan.headers { headerLines.append("      \(jsString(key)): \(jsString(value)),") }
            headerLines.append("    },")
            options.append(headerLines.joined(separator: "\n"))
        }
        if let body = plan.jsonBody ?? plan.rawBody {
            options.append("    data: \(jsBodyLiteral(body)),")
        } else if let pairs = plan.formPairs {
            options.append("    data: \(jsString(formEncoded(pairs))),")
        } else if plan.multipartParts != nil {
            options.append("    data: form,")
        } else if let count = plan.binaryByteCount {
            if let path = plan.binaryFilePath {
                options.append("    data: fs.readFileSync(\(jsString(path))), // \(count) bytes")
            } else {
                options.append("    // Binary body (\(count) bytes) — pass a Buffer here.")
            }
        } else if let comment = plan.placeholderComment {
            options.append("    // \(comment)")
        }
        if let basic = plan.basicAuth {
            options.append("    auth: { username: \(jsString(basic.user)), password: \(jsString(basic.password)) },")
        }
        if let digest = plan.digestAuth {
            options.append("    // Digest auth (user: \(digest.user)) — axios has no built-in support; use a library like @mhoc/axios-digest-auth.")
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
        var multipartLines: [String]?
        if let json = plan.jsonBody {
            bodyDecl = "body := strings.NewReader(\(goBodyString(json)))"
        } else if let pairs = plan.formPairs {
            bodyDecl = "body := strings.NewReader(\(goBodyString(formEncoded(pairs))))"
        } else if let parts = plan.multipartParts {
            var ml = ["var buf bytes.Buffer", "w := multipart.NewWriter(&buf)"]
            for (name, value) in textParts(parts) {
                ml.append("if err := w.WriteField(\(goString(name)), \(goString(value))); err != nil {")
                ml.append("\tpanic(err)")
                ml.append("}")
            }
            for file in fileParts(parts) {
                let disposition = "form-data; name=\"\(MultipartEncoder.escapeDispositionValue(file.name))\"; filename=\"\(MultipartEncoder.escapeDispositionValue(file.filename))\""
                ml.append("{")
                ml.append("\th := textproto.MIMEHeader{}")
                ml.append("\th.Set(\"Content-Disposition\", \(goString(disposition)))")
                ml.append("\th.Set(\"Content-Type\", \(goString(file.mime)))")
                ml.append("\tpart, err := w.CreatePart(h)")
                ml.append("\tif err != nil {")
                ml.append("\t\tpanic(err)")
                ml.append("\t}")
                ml.append("\tf, err := os.Open(\(goString(file.path)))")
                ml.append("\tif err != nil {")
                ml.append("\t\tpanic(err)")
                ml.append("\t}")
                ml.append("\tif _, err := io.Copy(part, f); err != nil {")
                ml.append("\t\tpanic(err)")
                ml.append("\t}")
                ml.append("\tf.Close()")
                ml.append("}")
            }
            ml.append("w.Close()")
            multipartLines = ml
            bodyArg = "&buf"
        } else if let raw = plan.rawBody {
            bodyDecl = "body := strings.NewReader(\(goBodyString(raw)))"
        } else if let count = plan.binaryByteCount {
            if let path = plan.binaryFilePath {
                bodyDecl = "// Binary body (\(count) bytes)\n\tbody, err := os.Open(\(goString(path)))\n\tif err != nil {\n\t\tpanic(err)\n\t}"
            } else {
                bodyDecl = "// Binary body (\(count) bytes) — open a file instead:\n\tbody, _ := os.Open(\"/path/to/body\")"
            }
        }
        if bodyDecl != nil { bodyArg = "body" }

        var imports = ["\"fmt\"", "\"io\"", "\"net/http\""]
        if plan.jsonBody != nil || plan.formPairs != nil || plan.rawBody != nil { imports.append("\"strings\"") }
        if plan.binaryByteCount != nil { imports.append("\"os\"") }
        if let parts = plan.multipartParts {
            imports.append("\"bytes\"")
            imports.append("\"mime/multipart\"")
            if !fileParts(parts).isEmpty {
                imports.append("\"net/textproto\"")
                imports.append("\"os\"")
            }
        }

        var lines = ["package main", "", "import ("]
        for imp in imports.sorted() { lines.append("\t\(imp)") }
        lines.append(")")
        lines.append("")
        lines.append("func main() {")
        if let multipartLines {
            for ml in multipartLines { lines.append("\t\(ml)") }
        } else if let bodyDecl { lines.append("\t\(bodyDecl)") }
        else if let comment = plan.placeholderComment { lines.append("\t// \(comment)") }
        lines.append("\treq, err := http.NewRequest(\(goString(plan.method)), \(goString(plan.url)), \(bodyArg))")
        lines.append("\tif err != nil {")
        lines.append("\t\tpanic(err)")
        lines.append("\t}")
        for (key, value) in plan.headers {
            lines.append("\treq.Header.Set(\(goString(key)), \(goString(value)))")
        }
        if plan.multipartParts != nil {
            lines.append("\treq.Header.Set(\"Content-Type\", w.FormDataContentType())")
        }
        if let basic = plan.basicAuth {
            lines.append("\treq.SetBasicAuth(\(goString(basic.user)), \(goString(basic.password)))")
        }
        if let digest = plan.digestAuth {
            lines.append("\t// Digest auth (user: \(digest.user)) — net/http has no built-in support; use a digest-capable transport like github.com/icholy/digest.")
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
