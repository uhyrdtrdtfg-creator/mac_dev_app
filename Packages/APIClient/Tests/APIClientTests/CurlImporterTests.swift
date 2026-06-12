import Testing
import Foundation
@testable import APIClient

private func header(_ request: CurlImportedRequest, _ name: String) -> String? {
    request.headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
}

@Test func curlImportChromeCopyAsCurl() throws {
    let curl = """
    curl 'https://api.example.com/v1/search?q=swift' \\
      -H 'accept: application/json, text/plain, */*' \\
      -H 'accept-language: en-US,en;q=0.9' \\
      -H $'cookie: session=abc123; theme=caf\\u00e9' \\
      -H 'sec-ch-ua: "Chromium";v="124", "Not-A.Brand";v="99"' \\
      --data-raw $'{"query":"hello\\nworld"}' \\
      --compressed
    """
    let request = try #require(CurlImporter.parseFirst(curl))
    #expect(request.url == "https://api.example.com/v1/search?q=swift")
    #expect(request.method == "POST")
    #expect(header(request, "cookie") == "session=abc123; theme=café")
    #expect(header(request, "sec-ch-ua") == "\"Chromium\";v=\"124\", \"Not-A.Brand\";v=\"99\"")
    guard case .data(let body) = request.body else {
        Issue.record("expected data body, got \(String(describing: request.body))")
        return
    }
    #expect(body == "{\"query\":\"hello\nworld\"}")
}

@Test func curlImportMultilineContinuation() throws {
    let curl = """
    curl -X PUT \\
      -H 'Authorization: Bearer token123' \\
      -H 'Content-Type: application/json' \\
      -d '{"key":"value"}' \\
      'https://api.example.com/resource'
    """
    let request = try #require(CurlImporter.parseFirst(curl))
    #expect(request.method == "PUT")
    #expect(request.url == "https://api.example.com/resource")
    #expect(header(request, "Authorization") == "Bearer token123")
    guard case .data(let body) = request.body else {
        Issue.record("expected data body")
        return
    }
    #expect(body == "{\"key\":\"value\"}")
}

@Test func curlImportDataImpliesPOST() throws {
    let request = try #require(CurlImporter.parseFirst("curl -d 'a=1' -d 'b=2' https://example.com/form"))
    #expect(request.method == "POST")
    guard case .data(let body) = request.body else {
        Issue.record("expected data body")
        return
    }
    #expect(body == "a=1&b=2")
    #expect(header(request, "Content-Type") == "application/x-www-form-urlencoded")
}

@Test func curlImportExplicitContentTypeNotOverridden() throws {
    let request = try #require(CurlImporter.parseFirst("curl -H 'Content-Type: application/json' -d '{\"a\":1}' https://example.com"))
    #expect(request.headers.filter { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }.count == 1)
    #expect(header(request, "Content-Type") == "application/json")
}

@Test func curlImportGetMovesDataToQuery() throws {
    let request = try #require(CurlImporter.parseFirst("curl -G -d 'q=hello' -d 'limit=5' 'https://example.com/search'"))
    #expect(request.method == "GET")
    #expect(request.url == "https://example.com/search?q=hello&limit=5")
    #expect(request.body == nil)
    #expect(header(request, "Content-Type") == nil)
}

@Test func curlImportGetAppendsToExistingQuery() throws {
    let request = try #require(CurlImporter.parseFirst("curl --get --data 'b=2' 'https://example.com/search?a=1'"))
    #expect(request.url == "https://example.com/search?a=1&b=2")
}

@Test func curlImportMultipartForm() throws {
    let curl = "curl -F 'name=Jane Doe' -F 'avatar=@/tmp/photo.png;type=image/png;filename=me.png' https://example.com/upload"
    let request = try #require(CurlImporter.parseFirst(curl))
    #expect(request.method == "POST")
    guard case .multipart(let parts) = request.body else {
        Issue.record("expected multipart body, got \(String(describing: request.body))")
        return
    }
    #expect(parts.count == 2)
    #expect(parts[0].name == "name")
    #expect(parts[0].kind == .text("Jane Doe"))
    #expect(parts[1].name == "avatar")
    #expect(parts[1].kind == .file(path: "/tmp/photo.png", filename: "me.png", mimeType: "image/png"))
}

@Test func curlImportBasicAuth() throws {
    let request = try #require(CurlImporter.parseFirst("curl -u admin:s3cret https://example.com/private"))
    guard case .basicAuth(let username, let password) = request.auth else {
        Issue.record("expected basicAuth, got \(String(describing: request.auth))")
        return
    }
    #expect(username == "admin")
    #expect(password == "s3cret")
}

@Test func curlImportHeaderValueWithColons() throws {
    let request = try #require(CurlImporter.parseFirst("curl -H 'X-Window: 12:30:45' -H \"X-Note: a:b\" https://example.com"))
    #expect(header(request, "X-Window") == "12:30:45")
    #expect(header(request, "X-Note") == "a:b")
}

@Test func curlImportUnknownFlagsTolerated() throws {
    let curl = "curl -sSL --compressed -k --insecure --retry 3 --output /dev/null --totally-made-up-flag 'https://example.com/api'"
    let request = try #require(CurlImporter.parseFirst(curl))
    #expect(request.url == "https://example.com/api")
    #expect(request.method == "GET")
    #expect(request.warnings.contains { $0.contains("--totally-made-up-flag") })
}

@Test func curlImportJSONFlag() throws {
    let request = try #require(CurlImporter.parseFirst("curl --json '{\"a\":1}' https://example.com/api"))
    #expect(request.method == "POST")
    #expect(header(request, "Content-Type") == "application/json")
    #expect(header(request, "Accept") == "application/json")
    guard case .data(let body) = request.body else {
        Issue.record("expected data body")
        return
    }
    #expect(body == "{\"a\":1}")
}

@Test func curlImportHeadAndHeaderSugar() throws {
    let request = try #require(CurlImporter.parseFirst("curl -I -A 'MyAgent/1.0' -e 'https://referrer.example' -b 'k=v; j=w' https://example.com"))
    #expect(request.method == "HEAD")
    #expect(header(request, "User-Agent") == "MyAgent/1.0")
    #expect(header(request, "Referer") == "https://referrer.example")
    #expect(header(request, "Cookie") == "k=v; j=w")
}

@Test func curlImportAttachedShortFlagValue() throws {
    let request = try #require(CurlImporter.parseFirst("curl -XDELETE https://example.com/items/5"))
    #expect(request.method == "DELETE")
}

@Test func curlImportDataUrlencode() throws {
    let request = try #require(CurlImporter.parseFirst("curl --data-urlencode 'msg=hello world&more' https://example.com"))
    guard case .data(let body) = request.body else {
        Issue.record("expected data body")
        return
    }
    #expect(body == "msg=hello%20world%26more")
}

@Test func curlImportMultipleCommands() throws {
    let text = """
    curl https://example.com/one
    curl -X POST -d 'x=1' https://example.com/two && curl https://example.com/three
    """
    let requests = CurlImporter.parse(text)
    #expect(requests.count == 3)
    #expect(requests[0].url == "https://example.com/one")
    #expect(requests[1].method == "POST")
    #expect(requests[1].url == "https://example.com/two")
    #expect(requests[2].url == "https://example.com/three")
}

@Test func curlImportSkipsNonCurlCommands() throws {
    let requests = CurlImporter.parse("echo hi && curl https://example.com/api")
    #expect(requests.count == 1)
    #expect(requests[0].url == "https://example.com/api")
}

@Test func curlImportNoURLReturnsNothing() {
    #expect(CurlImporter.parse("curl -X POST -H 'a: b'").isEmpty)
    #expect(CurlImporter.parse("not a curl command").isEmpty)
}

@Test func curlImportToSavedRequests() throws {
    let text = """
    curl -u admin:pw -H 'Content-Type: application/json' -d '{"a":1}' https://example.com/api/items
    curl -d 'name=Jane+Doe&role=dev' https://example.com/api/users
    """
    let saved = ImportExportService.importCurlCommands(text)
    #expect(saved.count == 2)

    #expect(saved[0].method == "POST")
    #expect(saved[0].url == "https://example.com/api/items")
    #expect(saved[0].bodyType == "json")
    let basic = Data("admin:pw".utf8).base64EncodedString()
    #expect(saved[0].headers.contains { $0.key == "Authorization" && $0.value == "Basic \(basic)" })
    guard case .json(let raw) = saved[0].body else {
        Issue.record("expected json body")
        return
    }
    #expect(raw == "{\"a\":1}")

    #expect(saved[1].bodyType == "formData")
    guard case .formData(let pairs) = saved[1].body else {
        Issue.record("expected formData body")
        return
    }
    #expect(pairs.map { [$0.key, $0.value] } == [["name", "Jane Doe"], ["role", "dev"]])
    #expect(saved[1].tagList == ["cURL Import"])
}

@Test func curlImportUnknownValueOptionDoesNotEatURL() throws {
    let request = try #require(CurlImporter.parseFirst("curl --max-filesize 100M https://real.example.com"))
    #expect(request.url == "https://real.example.com")
}

@Test func curlImportTrulyUnknownValueOptionPrefersURLLikeToken() throws {
    // Not in any curated list: the option's argument becomes a stray positional,
    // but the URL-looking token must still win.
    let request = try #require(CurlImporter.parseFirst("curl --definitely-not-a-real-flag whatever https://real.example.com/path"))
    #expect(request.url == "https://real.example.com/path")
}

@Test func curlImportUnixSocketKeepsURL() throws {
    let request = try #require(CurlImporter.parseFirst("curl --unix-socket /var/run/docker.sock http://localhost/v1.41/containers/json"))
    #expect(request.url == "http://localhost/v1.41/containers/json")
}
