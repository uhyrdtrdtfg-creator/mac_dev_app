import Testing
import Foundation
@testable import APIClient

// MARK: - Fixtures

private func makeTempFile(named name: String, contents: Data) throws -> (dir: URL, file: URL) {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let file = dir.appendingPathComponent(name)
    try contents.write(to: file)
    return (dir, file)
}

private let multipartCodeGenRequest = CodeGenRequest(
    method: .post,
    url: "https://api.example.com/upload",
    headers: [KeyValuePair(key: "X-Custom", value: "a\"b")],
    body: .multipart([
        MultipartPart(name: "field one", kind: .text("say \"hi\"")),
        MultipartPart(name: "中文✓", kind: .text("value 中文")),
        MultipartPart(name: "attachment", kind: .file(path: "/tmp/héllo 你好.png", filename: "héllo 你好.png", mimeType: "image/png")),
    ]),
    auth: .bearerToken("tok123")
)

// MARK: - Encoder bytes

@Test func multipartEncoderMatchesHandWrittenPayload() throws {
    let fileBytes = Data([0x89, 0x50, 0x4E, 0x47, 0x00, 0xFF, 0x0D, 0x0A])
    let (dir, file) = try makeTempFile(named: "héllo 你好.png", contents: fileBytes)
    defer { try? FileManager.default.removeItem(at: dir) }

    let parts = [
        MultipartPart(name: "field one", kind: .text("value 1")),
        MultipartPart(name: "quo\"te\\slash", kind: .text("中文✓")),
        MultipartPart(name: "файл", kind: .file(path: file.path, filename: "héllo 你好.png", mimeType: "image/png")),
    ]
    let encoded = try MultipartEncoder.encode(parts: parts, boundary: "BOUNDARY-123")

    var expected = Data()
    expected.append(Data("--BOUNDARY-123\r\n".utf8))
    expected.append(Data("Content-Disposition: form-data; name=\"field one\"\r\n\r\n".utf8))
    expected.append(Data("value 1\r\n".utf8))
    expected.append(Data("--BOUNDARY-123\r\n".utf8))
    expected.append(Data("Content-Disposition: form-data; name=\"quo\\\"te\\\\slash\"\r\n\r\n".utf8))
    expected.append(Data("中文✓\r\n".utf8))
    expected.append(Data("--BOUNDARY-123\r\n".utf8))
    expected.append(Data("Content-Disposition: form-data; name=\"файл\"; filename=\"héllo 你好.png\"\r\n".utf8))
    expected.append(Data("Content-Type: image/png\r\n\r\n".utf8))
    expected.append(fileBytes)
    expected.append(Data("\r\n".utf8))
    expected.append(Data("--BOUNDARY-123--\r\n".utf8))
    #expect(encoded == expected)
}

@Test func multipartEncoderUsesCRLFOnly() throws {
    let encoded = try MultipartEncoder.encode(parts: [
        MultipartPart(name: "a", kind: .text("x")),
        MultipartPart(name: "b", kind: .text("y")),
    ], boundary: "B")
    let text = String(decoding: encoded, as: UTF8.self)
    let withoutCRLF = text.replacingOccurrences(of: "\r\n", with: "")
    #expect(!withoutCRLF.contains("\n"))
    #expect(!withoutCRLF.contains("\r"))
    #expect(text.hasSuffix("--B--\r\n"))
}

@Test func multipartEncoderSkipsDisabledParts() throws {
    let encoded = try MultipartEncoder.encode(parts: [
        MultipartPart(name: "keep", kind: .text("1")),
        MultipartPart(name: "skip", kind: .text("2"), isEnabled: false),
    ], boundary: "B")
    let text = String(decoding: encoded, as: UTF8.self)
    #expect(text.contains("name=\"keep\""))
    #expect(!text.contains("skip"))
}

@Test func multipartEncoderMissingFileThrowsNamedError() {
    let parts = [MultipartPart(name: "doc", kind: .file(path: "/nonexistent/dir/x.bin", filename: "x.bin", mimeType: ""))]
    #expect(throws: MultipartEncoderError.unreadableFile(partName: "doc", path: "/nonexistent/dir/x.bin")) {
        _ = try MultipartEncoder.encode(parts: parts, boundary: "B")
    }
    do {
        _ = try MultipartEncoder.encode(parts: parts, boundary: "B")
        Issue.record("Expected encode to throw")
    } catch {
        #expect(error.localizedDescription.contains("doc"))
        #expect(error.localizedDescription.contains("/nonexistent/dir/x.bin"))
    }
}

@Test func multipartEncoderFallsBackToOctetStreamAndPathFilename() throws {
    let (dir, file) = try makeTempFile(named: "data.unknownext", contents: Data([1, 2, 3]))
    defer { try? FileManager.default.removeItem(at: dir) }
    let encoded = try MultipartEncoder.encode(parts: [
        MultipartPart(name: "f", kind: .file(path: file.path, filename: "", mimeType: "")),
    ], boundary: "B")
    let text = String(decoding: encoded, as: UTF8.self)
    #expect(text.contains("filename=\"data.unknownext\""))
    #expect(text.contains("Content-Type: application/octet-stream"))
}

@Test func generateBoundaryIsUnique() {
    let a = MultipartEncoder.generateBoundary()
    let b = MultipartEncoder.generateBoundary()
    #expect(a != b)
    #expect(!a.isEmpty)
}

// MARK: - MIME detection

@Test(arguments: [
    ("photo.png", "image/png"),
    ("photo.jpg", "image/jpeg"),
    ("doc.pdf", "application/pdf"),
    ("payload.json", "application/json"),
    ("notes.txt", "text/plain"),
    ("page.html", "text/html"),
    ("archive.zip", "application/zip"),
    ("mystery.qqqqzz", "application/octet-stream"),
    ("no-extension", "application/octet-stream"),
])
func mimeDetection(filename: String, expected: String) {
    #expect(MultipartEncoder.mimeType(forPath: "/tmp/\(filename)") == expected)
}

// MARK: - Boundary parsing

@Test func boundaryFromContentType() {
    #expect(MultipartEncoder.boundary(fromContentType: "multipart/form-data; boundary=abc123") == "abc123")
    #expect(MultipartEncoder.boundary(fromContentType: "multipart/form-data; charset=utf-8; Boundary=\"quoted-b\"") == "quoted-b")
    #expect(MultipartEncoder.boundary(fromContentType: "multipart/form-data") == nil)
    #expect(MultipartEncoder.boundary(fromContentType: "application/json") == nil)
}

// MARK: - buildURLRequest integration

@Test func buildURLRequestMultipartSetsBoundaryContentType() throws {
    let body = RequestBody.multipart([MultipartPart(name: "a", kind: .text("1"))])
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://example.com/up", headers: [], queryParams: [], body: body, auth: nil)
    let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    let boundary = try #require(MultipartEncoder.boundary(fromContentType: contentType))
    let bodyText = String(decoding: try #require(request.httpBody), as: UTF8.self)
    #expect(bodyText.contains("--\(boundary)\r\n"))
    #expect(bodyText.hasSuffix("--\(boundary)--\r\n"))
}

@Test func buildURLRequestMultipartAppendsBoundaryToUserContentType() throws {
    let body = RequestBody.multipart([MultipartPart(name: "a", kind: .text("1"))])
    let headers = [KeyValuePair(key: "Content-Type", value: "multipart/form-data")]
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://example.com/up", headers: headers, queryParams: [], body: body, auth: nil)
    let contentType = try #require(request.value(forHTTPHeaderField: "Content-Type"))
    #expect(contentType.hasPrefix("multipart/form-data; boundary="))
    let boundary = try #require(MultipartEncoder.boundary(fromContentType: contentType))
    #expect(String(decoding: try #require(request.httpBody), as: UTF8.self).contains("--\(boundary)--"))
}

@Test func buildURLRequestMultipartUsesUserBoundary() throws {
    let body = RequestBody.multipart([MultipartPart(name: "a", kind: .text("1"))])
    let headers = [KeyValuePair(key: "Content-Type", value: "multipart/form-data; boundary=MyBoundary99")]
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://example.com/up", headers: headers, queryParams: [], body: body, auth: nil)
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "multipart/form-data; boundary=MyBoundary99")
    #expect(String(decoding: try #require(request.httpBody), as: UTF8.self).contains("--MyBoundary99\r\n"))
}

@Test func buildURLRequestMultipartMissingFilePropagatesError() {
    let body = RequestBody.multipart([MultipartPart(name: "doc", kind: .file(path: "/gone/file.bin", filename: "file.bin", mimeType: ""))])
    #expect(throws: MultipartEncoderError.self) {
        try HTTPClientService.buildURLRequest(method: .post, url: "https://example.com/up", headers: [], queryParams: [], body: body, auth: nil)
    }
}

// MARK: - Binary body file helpers

@Test func binaryBodyLoadMissingFileError() {
    #expect(throws: BinaryBodyError.fileUnreadable(path: "/gone/file.bin")) {
        _ = try BinaryBodyFile.load(path: "/gone/file.bin")
    }
    #expect(throws: BinaryBodyError.noFileSelected) {
        _ = try BinaryBodyFile.load(path: "")
    }
}

@Test func binaryBodyHeadersAddContentTypeOnlyWhenAbsent() {
    let added = BinaryBodyFile.headers([KeyValuePair(key: "Accept", value: "*/*")], addingContentType: "image/png")
    #expect(added.contains { $0.key == "Content-Type" && $0.value == "image/png" })
    let untouched = BinaryBodyFile.headers([KeyValuePair(key: "content-type", value: "application/zip")], addingContentType: "image/png")
    #expect(untouched.count == 1)
    let empty = BinaryBodyFile.headers([], addingContentType: "")
    #expect(empty.isEmpty)
}

// MARK: - Codable stability

@Test func multipartPartCodableRoundtrip() throws {
    let parts = [
        MultipartPart(name: "t", kind: .text("v")),
        MultipartPart(name: "f", kind: .file(path: "/tmp/a.png", filename: "a.png", mimeType: "image/png"), isEnabled: false),
    ]
    let decoded = try JSONDecoder().decode([MultipartPart].self, from: JSONEncoder().encode(parts))
    #expect(decoded == parts)
}

@Test func requestBodyMultipartCodableRoundtrip() throws {
    let body = RequestBody.multipart([MultipartPart(name: "n", kind: .text("v"))])
    let decoded = try JSONDecoder().decode(RequestBody.self, from: JSONEncoder().encode(body))
    if case .multipart(let parts) = decoded {
        #expect(parts.count == 1)
        #expect(parts[0].name == "n")
        #expect(parts[0].kind == .text("v"))
    } else {
        Issue.record("Expected .multipart case")
    }
}

@Test func requestBodyOldPersistedCasesStillDecode() throws {
    // JSON shapes captured from the pre-multipart encoder — must keep decoding.
    let oldJSON = Data(#"{"json":{"_0":"{\"a\":1}"}}"#.utf8)
    if case .json(let text) = try JSONDecoder().decode(RequestBody.self, from: oldJSON) {
        #expect(text == #"{"a":1}"#)
    } else {
        Issue.record("Expected .json case")
    }
    let oldBinary = Data(#"{"binary":{"_0":"AQID"}}"#.utf8)
    if case .binary(let data) = try JSONDecoder().decode(RequestBody.self, from: oldBinary) {
        #expect(data == Data([1, 2, 3]))
    } else {
        Issue.record("Expected .binary case")
    }
}

// MARK: - OpenTabModel round-trips

@Test func openTabMultipartPartsAccessorRoundtrip() {
    let tab = OpenTabModel()
    let parts = [MultipartPart(name: "x", kind: .file(path: "/tmp/x.bin", filename: "x.bin", mimeType: "application/octet-stream"))]
    tab.multipartParts = parts
    #expect(tab.multipartParts == parts)
}

@Test func restoringSavedBinaryBodyNoLongerDropsIt() throws {
    // Regression: `case .binary: break` used to silently drop the body on restore.
    let tab = OpenTabModel()
    let payload = Data([0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x0D, 0x0A])
    tab.restoreBinaryBody(payload)
    #expect(tab.bodyType == BodyType.binary.rawValue)
    #expect(!tab.binaryFilePath.isEmpty)
    #expect(try BinaryBodyFile.load(path: tab.binaryFilePath) == payload)
    try? FileManager.default.removeItem(atPath: tab.binaryFilePath)
}

// MARK: - Code generation

@Test func swiftMultipartCodeGen() {
    let code = RequestCodeGenerator.generate(.swiftURLSession, request: multipartCodeGenRequest)
    #expect(code.contains(#"let boundary = "Boundary-\(UUID().uuidString)""#))
    #expect(code.contains(#"request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")"#))
    #expect(code.contains(#"name=\"field one\""#))
    #expect(code.contains(#"filename=\"héllo 你好.png\""#))
    #expect(code.contains("Content-Type: image/png"))
    #expect(code.contains("body.append(try Data(contentsOf: URL(fileURLWithPath: \"/tmp/héllo 你好.png\")))"))
    #expect(code.contains(#"--\(boundary)--"#))
}

@Test func pythonMultipartCodeGen() {
    let code = RequestCodeGenerator.generate(.pythonRequests, request: multipartCodeGenRequest)
    #expect(code.contains("data = {"))
    #expect(code.contains("'field one': 'say \"hi\"',"))
    #expect(code.contains("files = {"))
    #expect(code.contains("'attachment': ('héllo 你好.png', open('/tmp/héllo 你好.png', 'rb'), 'image/png'),"))
    #expect(code.contains("data=data"))
    #expect(code.contains("files=files"))
}

@Test func jsFetchMultipartCodeGen() {
    let code = RequestCodeGenerator.generate(.jsFetch, request: multipartCodeGenRequest)
    #expect(code.contains("const form = new FormData();"))
    #expect(code.contains("form.append(\"field one\", \"say \\\"hi\\\"\");"))
    #expect(code.contains("// File part \"attachment\""))
    #expect(code.contains("body: form,"))
    #expect(!code.contains("\"Content-Type\":")) // fetch sets the boundary header itself
}

@Test func axiosMultipartCodeGen() {
    let code = RequestCodeGenerator.generate(.nodeAxios, request: multipartCodeGenRequest)
    #expect(code.contains("const FormData = require(\"form-data\");"))
    #expect(code.contains("const fs = require(\"fs\");"))
    #expect(code.contains("form.append(\"attachment\", fs.createReadStream(\"/tmp/héllo 你好.png\"), { filename: \"héllo 你好.png\", contentType: \"image/png\" });"))
    #expect(code.contains("...form.getHeaders(),"))
    #expect(code.contains("data: form,"))
}

@Test func goMultipartCodeGen() {
    let code = RequestCodeGenerator.generate(.goNetHTTP, request: multipartCodeGenRequest)
    #expect(code.contains("\"mime/multipart\""))
    #expect(code.contains("\"net/textproto\""))
    #expect(code.contains("w := multipart.NewWriter(&buf)"))
    #expect(code.contains("if err := w.WriteField(\"field one\", \"say \\\"hi\\\"\"); err != nil {"))
    #expect(code.contains("part, err := w.CreatePart(h)"))
    #expect(code.contains("os.Open(\"/tmp/héllo 你好.png\")"))
    #expect(code.contains("req.Header.Set(\"Content-Type\", w.FormDataContentType())"))
    #expect(code.contains("http.NewRequest(\"POST\", \"https://api.example.com/upload\", &buf)"))
}

@Test func binaryPathFlavorCodeGenAllLanguages() {
    let request = CodeGenRequest(
        method: .post, url: "https://x.dev/raw",
        headers: [KeyValuePair(key: "Content-Type", value: "application/zip")],
        body: .binary(Data([1, 2, 3])),
        binaryFilePath: "/tmp/payload.zip"
    )
    let swift = RequestCodeGenerator.generate(.swiftURLSession, request: request)
    #expect(swift.contains("request.httpBody = try Data(contentsOf: URL(fileURLWithPath: \"/tmp/payload.zip\"))"))
    let python = RequestCodeGenerator.generate(.pythonRequests, request: request)
    #expect(python.contains("data = open('/tmp/payload.zip', \"rb\").read()"))
    let fetch = RequestCodeGenerator.generate(.jsFetch, request: request)
    #expect(fetch.contains("const { readFileSync } = require(\"node:fs\");"))
    #expect(fetch.contains("body: readFileSync(\"/tmp/payload.zip\"), // 3 bytes"))
    let axios = RequestCodeGenerator.generate(.nodeAxios, request: request)
    #expect(axios.contains("data: fs.readFileSync(\"/tmp/payload.zip\"), // 3 bytes"))
    let go = RequestCodeGenerator.generate(.goNetHTTP, request: request)
    #expect(go.contains("body, err := os.Open(\"/tmp/payload.zip\")"))
}

// MARK: - Generated multipart snippets pass real syntax checkers

private func syntaxCheck(_ code: String, ext: String, command: [String]) throws -> Bool {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("multipart-codegen-\(UUID().uuidString)")
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

@Test func generatedMultipartPythonCompiles() throws {
    guard FileManager.default.fileExists(atPath: "/usr/bin/python3") else { return }
    let code = RequestCodeGenerator.generate(.pythonRequests, request: multipartCodeGenRequest)
    #expect(try syntaxCheck(code, ext: "py", command: ["/usr/bin/python3", "-m", "py_compile"]))
}

@Test func generatedMultipartJSParses() throws {
    let nodePaths = ["/opt/homebrew/bin/node", "/usr/local/bin/node"]
    guard let node = nodePaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
    for lang in [CodeGenLanguage.jsFetch, .nodeAxios] {
        let code = RequestCodeGenerator.generate(lang, request: multipartCodeGenRequest)
        #expect(try syntaxCheck(code, ext: "js", command: [node, "--check"]), "\(lang.rawValue) multipart snippet failed node --check")
    }
}

@Test func generatedMultipartGoCompiles() throws {
    let goPaths = ["/usr/local/go/bin/go", "/opt/homebrew/bin/go"]
    guard let go = goPaths.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
    let binaryPathRequest = CodeGenRequest(
        method: .post, url: "https://x.dev/raw",
        body: .binary(Data([1, 2, 3])), binaryFilePath: "/tmp/payload.zip"
    )
    for request in [multipartCodeGenRequest, binaryPathRequest] {
        let code = RequestCodeGenerator.generate(.goNetHTTP, request: request)
        #expect(try syntaxCheck(code, ext: "go", command: [go, "build", "-o", "/dev/null"]), "Go multipart snippet failed to compile")
    }
}

// MARK: - cURL export

@Test func curlExportMultipartUsesFormFlags() {
    var request = URLRequest(url: URL(string: "https://x.dev/upload")!)
    request.httpMethod = "POST"
    request.setValue("multipart/form-data; boundary=ignored", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer tok", forHTTPHeaderField: "Authorization")

    let curl = CurlHelper.export(request, multipartParts: [
        MultipartPart(name: "name", kind: .text("Bob's value")),
        MultipartPart(name: "skip", kind: .text("no"), isEnabled: false),
        MultipartPart(name: "doc", kind: .file(path: "/tmp/a.png", filename: "renamed.png", mimeType: "image/png")),
    ])
    #expect(curl.contains("-F 'name=Bob'\\''s value'"))
    #expect(curl.contains("-F 'doc=@/tmp/a.png;type=image/png;filename=renamed.png'"))
    #expect(!curl.contains("skip"))
    #expect(!curl.contains("Content-Type")) // curl generates its own boundary
    #expect(curl.contains("-H 'Authorization: Bearer tok'"))
    #expect(curl.contains("'https://x.dev/upload'"))
    #expect(!curl.contains("-X POST")) // -F already implies POST
}

// MARK: - HAR mapping

@Test func harExportSavedMultipartAndMapBack() throws {
    let saved = SavedRequestModel(name: "Upload", method: "POST", url: "https://api.example.com/upload")
    saved.bodyType = "Multipart"
    saved.body = .multipart([
        MultipartPart(name: "comment", kind: .text("héllo")),
        MultipartPart(name: "photo", kind: .file(path: "/tmp/pic.png", filename: "pic.png", mimeType: "image/png")),
        MultipartPart(name: "disabled", kind: .text("x"), isEnabled: false),
    ])

    let decoded = try HARCodec.decode(HARCodec.encode(requests: [saved], historyEntries: []))
    let postData = try #require(decoded.entries[0].postData)
    #expect(postData.mimeType == "multipart/form-data")
    #expect(postData.params.count == 2)
    #expect(postData.params.contains { $0.name == "comment" && $0.value == "héllo" && $0.fileName == nil })
    #expect(postData.params.contains { $0.name == "photo" && $0.fileName == "pic.png" && $0.contentType == "image/png" && $0.value.isEmpty })

    let mapped = HARCodec.mapToRequests(decoded)
    if case .multipart(let parts)? = mapped[0].body {
        #expect(parts.count == 2)
        #expect(parts[0].kind == .text("héllo"))
        #expect(parts[1].kind == .file(path: "", filename: "pic.png", mimeType: "image/png"))
    } else {
        Issue.record("Expected .multipart body")
    }
}

@Test func harExportMultipartHistoryEntry() throws {
    let item = HTTPHistoryModel(requestMethod: "POST", requestURL: "https://example.com/up", responseStatus: 200, duration: 0.1, responseSize: 0)
    item.bodyType = "Multipart"
    item.requestBodyJSON = try JSONEncoder().encode([
        MultipartPart(name: "a", kind: .text("1")),
        MultipartPart(name: "f", kind: .file(path: "/tmp/x.pdf", filename: "x.pdf", mimeType: "application/pdf")),
    ])
    let decoded = try HARCodec.decode(HARCodec.encode(requests: [], historyEntries: [item]))
    let postData = try #require(decoded.entries[0].postData)
    #expect(postData.mimeType == "multipart/form-data")
    #expect(postData.params.contains { $0.name == "f" && $0.fileName == "x.pdf" && $0.contentType == "application/pdf" })
}

// MARK: - Postman collection round-trip

@Test func postmanExportImportMultipartRoundtrip() throws {
    let saved = SavedRequestModel(name: "Upload", method: "POST", url: "https://api.example.com/upload")
    saved.bodyType = "Multipart"
    saved.body = .multipart([
        MultipartPart(name: "comment", kind: .text("hi")),
        MultipartPart(name: "photo", kind: .file(path: "/tmp/pic.png", filename: "pic.png", mimeType: "image/png")),
    ])
    let json = ImportExportService.exportAsPostmanCollection([saved])
    #expect(json.contains("\"mode\" : \"formdata\"") || json.contains("\"mode\":\"formdata\""))

    let imported = ImportExportService.importPostmanCollection(json)
    #expect(imported.count == 1)
    if case .multipart(let parts)? = imported[0].body {
        #expect(parts.count == 2)
        #expect(parts[0].name == "comment")
        #expect(parts[0].kind == .text("hi"))
        #expect(parts[1].kind == .file(path: "/tmp/pic.png", filename: "pic.png", mimeType: "image/png"))
    } else {
        Issue.record("Expected .multipart body after Postman round-trip")
    }
}
