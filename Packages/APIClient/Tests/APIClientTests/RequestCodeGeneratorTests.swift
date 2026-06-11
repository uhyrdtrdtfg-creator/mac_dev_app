import Testing
import Foundation
@testable import APIClient

private let tricky = CodeGenRequest(
    method: .post,
    url: "https://api.example.com/items",
    headers: [KeyValuePair(key: "X-Custom", value: "a\"b")],
    queryParams: [KeyValuePair(key: "page", value: "1")],
    body: .json("{\"name\": \"say \\\"hi\\\"\",\n  \"note\": \"中文✓\"}"),
    auth: .bearerToken("tok123")
)

// MARK: - Query params merged into URL

@Test func swiftGETWithQuery() {
    let request = CodeGenRequest(method: .get, url: "https://api.example.com/users", queryParams: [
        KeyValuePair(key: "limit", value: "10"), KeyValuePair(key: "q", value: "a b"),
    ])
    let code = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(code.contains("limit=10"))
    #expect(code.contains("q=a%20b"))
    #expect(code.contains("request.httpMethod = \"GET\""))
    #expect(!code.contains("httpBody"))
}

@Test func disabledParamsAndHeadersSkipped() {
    let request = CodeGenRequest(
        method: .get, url: "https://x.dev/",
        headers: [KeyValuePair(key: "Skip", value: "no", isEnabled: false)],
        queryParams: [KeyValuePair(key: "skip", value: "no", isEnabled: false)]
    )
    for lang in CodeGenLanguage.allCases {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(!code.contains("Skip"))
        #expect(!code.contains("skip=no"))
    }
}

// MARK: - JSON body with quotes/newlines/unicode in all languages

@Test func swiftJSONBody() {
    let code = RequestCodeGenerator.generate(.swiftURLSession, request: tricky)
    #expect(code.contains("#\"\"\""))
    #expect(code.contains("\"name\": \"say \\\"hi\\\"\""))
    #expect(code.contains("中文✓"))
    #expect(code.contains("request.setValue(\"Bearer tok123\", forHTTPHeaderField: \"Authorization\")"))
    #expect(code.contains("request.setValue(\"application/json\", forHTTPHeaderField: \"Content-Type\")"))
    #expect(code.contains("page=1"))
}

@Test func pythonJSONBody() {
    let code = RequestCodeGenerator.generate(.pythonRequests, request: tricky)
    #expect(code.contains("import json"))
    #expect(code.contains("payload = json.loads("))
    #expect(code.contains("json=payload"))
    #expect(code.contains("中文✓"))
    #expect(code.contains("'Authorization': 'Bearer tok123'"))
    #expect(code.contains("requests.request('POST', url"))
}

@Test func jsFetchJSONBody() {
    let code = RequestCodeGenerator.generate(.jsFetch, request: tricky)
    #expect(code.contains("body: `"))
    #expect(code.contains("await fetch("))
    #expect(code.contains("\"Authorization\": \"Bearer tok123\""))
    #expect(code.contains("(async () => {"))
    #expect(code.hasSuffix("})();"))
}

@Test func axiosJSONBody() {
    let code = RequestCodeGenerator.generate(.nodeAxios, request: tricky)
    #expect(code.contains("require(\"axios\")"))
    #expect(code.contains("method: \"post\""))
    #expect(code.contains("data: `"))
    #expect(code.contains("\"Authorization\": \"Bearer tok123\""))
}

@Test func jsonBodyNeverInlinedAsObjectLiteral() {
    // Object-literal inlining drops __proto__, collapses duplicate keys, and
    // rounds big numbers — the body must stay a byte-faithful string literal.
    let request = CodeGenRequest(method: .post, url: "https://x.dev/", body: .json("{\"__proto__\": {\"x\": 1}, \"big\": 9007199254740993}"))
    for lang in [CodeGenLanguage.jsFetch, .nodeAxios] {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(code.contains("`{\"__proto__\""), "\(lang.rawValue) must keep the raw JSON text")
        #expect(code.contains("9007199254740993"))
    }
}

@Test func crlfBodyStaysByteFaithful() {
    let request = CodeGenRequest(method: .post, url: "https://x.dev/", body: .raw("a\r\nb\rc"))
    // Multiline/raw literals silently normalize CR — all languages must fall back
    // to single-line escaped literals carrying explicit \r escapes.
    let swift = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(swift.contains(#"let body = "a\r\nb\rc""#))
    let python = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(python.contains(#"data = 'a\r\nb\rc'"#))
    let fetch = RequestCodeGenerator.generate(.jsFetch, request: request)
    #expect(fetch.contains(#"body: "a\r\nb\rc""#))
    let go = RequestCodeGenerator.generate(.goNetHTTP, request: request)
    #expect(go.contains(#"strings.NewReader("a\r\nb\rc")"#))
    #expect(!go.contains("`"))
}

@Test func crlfInHeaderValueEscaped() {
    let request = CodeGenRequest(method: .get, url: "https://x.dev/", headers: [KeyValuePair(key: "X-Weird", value: "a\r\nb")])
    for lang in CodeGenLanguage.allCases {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(code.contains(#"a\r\nb"#), "\(lang.rawValue) must escape CRLF in header values")
    }
}

@Test func goJSONBody() {
    let code = RequestCodeGenerator.generate(.goNetHTTP, request: tricky)
    #expect(code.contains("strings.NewReader(`{"))
    #expect(code.contains("req.Header.Set(\"Authorization\", \"Bearer tok123\")"))
    #expect(code.contains("defer resp.Body.Close()"))
    #expect(code.contains("\"strings\""))
    #expect(code.contains("中文✓"))
}

// MARK: - Auth

@Test func basicAuthEncoding() {
    let request = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .basicAuth(username: "user", password: "pass"))
    // dXNlcjpwYXNz == base64("user:pass")
    let swift = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(swift.contains("Basic dXNlcjpwYXNz"))
    let fetch = RequestCodeGenerator.generate(.jsFetch, request: request)
    #expect(fetch.contains("Basic dXNlcjpwYXNz"))
    // Native forms where idiomatic
    let python = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(python.contains("auth=('user', 'pass')"))
    #expect(!python.contains("Basic "))
    let axios = RequestCodeGenerator.generate(.nodeAxios, request: request)
    #expect(axios.contains("auth: { username: \"user\", password: \"pass\" }"))
    let go = RequestCodeGenerator.generate(.goNetHTTP, request: request)
    #expect(go.contains("req.SetBasicAuth(\"user\", \"pass\")"))
}

@Test func digestAuthAllLanguages() {
    let request = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .digestAuth(username: "user", password: "pass"))
    // Native form where idiomatic
    let python = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(python.contains("from requests.auth import HTTPDigestAuth"))
    #expect(python.contains("auth=HTTPDigestAuth('user', 'pass')"))
    // Best-effort elsewhere: a comment noting digest auth, never a baked Authorization header
    for lang in [CodeGenLanguage.swiftURLSession, .jsFetch, .nodeAxios, .goNetHTTP] {
        let code = RequestCodeGenerator.generate(lang, request: request)
        #expect(code.contains("Digest auth (user: user)"), "\(lang.rawValue)")
        #expect(!code.contains("Authorization"), "\(lang.rawValue)")
    }
}

@Test func oauth2BearerInjection() {
    let withToken = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .oauth2(OAuth2Config(tokens: OAuth2Tokens(accessToken: "live-token-1"))))
    let without = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .oauth2(OAuth2Config()))
    for lang in CodeGenLanguage.allCases {
        #expect(RequestCodeGenerator.generate(lang, request: withToken).contains("Bearer live-token-1"), "\(lang.rawValue)")
        #expect(RequestCodeGenerator.generate(lang, request: without).contains("Bearer ACCESS_TOKEN"), "\(lang.rawValue)")
    }
}

@Test func apiKeyHeaderAndQuery() {
    let header = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .apiKey(key: "X-Api-Key", value: "k1", addTo: .header))
    #expect(RequestCodeGenerator.generate(.pythonRequests, request: header).contains("'X-Api-Key': 'k1'"))
    let query = CodeGenRequest(method: .get, url: "https://x.dev/", auth: .apiKey(key: "api_key", value: "k1", addTo: .queryParam))
    #expect(RequestCodeGenerator.generate(.pythonRequests, request: query).contains("api_key=k1"))
}

// MARK: - Form data

@Test func formDataAllLanguages() {
    // The app sends form pairs joined raw (no percent-escaping, duplicates kept) —
    // generated code must mirror those bytes, so no dicts/URLSearchParams.
    let request = CodeGenRequest(method: .post, url: "https://x.dev/login", body: .formData([
        KeyValuePair(key: "user", value: "a b"), KeyValuePair(key: "tag", value: "one"),
        KeyValuePair(key: "tag", value: "二"),
    ]))
    let expected = "user=a b&tag=one&tag=二"
    let swift = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(swift.contains(expected))
    #expect(swift.contains("application/x-www-form-urlencoded"))
    #expect(RequestCodeGenerator.generate(.pythonRequests, request: request).contains("data = '\(expected)'"))
    #expect(RequestCodeGenerator.generate(.jsFetch, request: request).contains("body: \"\(expected)\""))
    #expect(RequestCodeGenerator.generate(.nodeAxios, request: request).contains("data: \"\(expected)\""))
    #expect(RequestCodeGenerator.generate(.goNetHTTP, request: request).contains(expected))
}

// MARK: - Fallbacks

@Test func goBacktickFallback() {
    let request = CodeGenRequest(method: .post, url: "https://x.dev/", body: .raw("has `backtick`"))
    let code = RequestCodeGenerator.generate(.goNetHTTP, request: request)
    #expect(!code.contains("`has"))
    #expect(code.contains("\"has \\`".replacingOccurrences(of: "\\`", with: "`")))
}

@Test func pythonInvalidJSONFallsBackToData() {
    let request = CodeGenRequest(method: .post, url: "https://x.dev/", body: .json("{not json"))
    let code = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(code.contains("data ="))
    #expect(!code.contains("json.loads"))
}

@Test func jsInvalidJSONUsesTemplateLiteral() {
    let request = CodeGenRequest(method: .post, url: "https://x.dev/", body: .json("{`broken ${x}"))
    let code = RequestCodeGenerator.generate(.jsFetch, request: request)
    #expect(code.contains("body: `"))
    #expect(code.contains("\\`broken"))
    #expect(code.contains("\\${x}"))
}

@Test func contentTypeNotDuplicatedWhenUserSetsIt() {
    let request = CodeGenRequest(
        method: .post, url: "https://x.dev/",
        headers: [KeyValuePair(key: "content-type", value: "application/vnd.api+json")],
        body: .json("{}")
    )
    let code = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(code.contains("application/vnd.api+json"))
    #expect(!code.contains("\"application/json\""))
}

// MARK: - cURL round-trip

@Test func curlToCodeGenRequest() throws {
    let parsed = try #require(CurlHelper.parse("curl -X POST -H 'Content-Type: application/json' -d '{\"a\":1}' 'https://x.dev/items?q=1'"))
    let request = CodeGenRequest(curl: parsed)
    #expect(request.method == .post)
    if case .json(let body)? = request.body { #expect(body == "{\"a\":1}") } else { Issue.record("expected json body") }
    let code = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(code.contains("https://x.dev/items?q=1"))
}

// MARK: - Generated Python/JS snippets are syntactically valid (run real parsers)

private func syntaxCheck(_ code: String, ext: String, command: [String]) throws -> Bool {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("codegen-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: dir) }
    let file = dir.appendingPathComponent("snippet.\(ext)")
    try code.write(to: file, atomically: true, encoding: .utf8)

    let process = Process()
    process.executableURL = URL(fileURLWithPath: command[0])
    process.arguments = Array(command.dropFirst()) + [file.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    return process.terminationStatus == 0
}

@Test func generatedPythonCompiles() throws {
    guard FileManager.default.fileExists(atPath: "/usr/bin/python3") else { return }
    let code = RequestCodeGenerator.generate(.pythonRequests, request: tricky)
    #expect(try syntaxCheck(code, ext: "py", command: ["/usr/bin/python3", "-m", "py_compile"]))
}

@Test func generatedGoCompiles() throws {
    let goPaths = ["/usr/local/go/bin/go", "/opt/homebrew/bin/go"]
    guard let go = goPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
    let crlfRequest = CodeGenRequest(
        method: .post, url: "https://x.dev/items",
        headers: [KeyValuePair(key: "X-W", value: "v1\r\nv2")],
        body: .raw("a\r\nb\rc\nd `tick` ${x}"),
        auth: .basicAuth(username: "u", password: "p")
    )
    for request in [tricky, crlfRequest] {
        let code = RequestCodeGenerator.generate(.goNetHTTP, request: request)
        #expect(try syntaxCheck(code, ext: "go", command: [go, "build", "-o", "/dev/null"]), "Go snippet failed to compile")
    }
}

@Test func generatedJSParses() throws {
    let nodePaths = ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
    guard let node = nodePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
    for lang in [CodeGenLanguage.jsFetch, .nodeAxios] {
        let code = RequestCodeGenerator.generate(lang, request: tricky)
        #expect(try syntaxCheck(code, ext: "js", command: [node, "--check"]), "\(lang.rawValue) snippet failed node --check")
    }
}
