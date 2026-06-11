import Testing
import Foundation
@testable import APIClient

// MARK: - JSON tree model

private func buildTree(_ json: String) -> JSONTreeNode? {
    if case .tree(let root, _) = JSONTreeModel.build(jsonString: json) { return root }
    return nil
}

@Test func jsonTreeNestedObjectsAndArrays() throws {
    let root = try #require(buildTree(#"{"a":{"b":[1,2,{"c":"x"}]},"d":true}"#))
    #expect(root.path == "$")
    #expect(root.key == "$")
    #expect(root.totalChildCount == 2)

    let a = try #require(root.children?.first)
    #expect(a.path == "$.a")
    let b = try #require(a.children?.first)
    #expect(b.path == "$.a.b")
    #expect(b.totalChildCount == 3)

    let third = try #require(b.children?[2])
    #expect(third.path == "$.a.b[2]")
    #expect(third.key == "[2]")
    let c = try #require(third.children?.first)
    #expect(c.path == "$.a.b[2].c")
    #expect(c.value == .string("x"))

    let d = try #require(root.children?[1])
    #expect(d.path == "$.d")
    #expect(d.value == .bool(true))
}

@Test func jsonTreeKeyOrderPreserved() throws {
    let root = try #require(buildTree(#"{"z":1,"a":2,"m":3}"#))
    #expect(root.children?.map(\.key) == ["z", "a", "m"])
}

@Test func jsonTreePathBracketSyntax() throws {
    let root = try #require(buildTree(#"{"a b":1,"he\"llo":2,"valid_Key1":3,"0abc":4}"#))
    let paths = root.children?.map(\.path) ?? []
    #expect(paths[0] == "$[\"a b\"]")
    #expect(paths[1] == "$[\"he\\\"llo\"]")
    #expect(paths[2] == "$.valid_Key1")
    #expect(paths[3] == "$[\"0abc\"]")
}

@Test func jsonTreeScalarKinds() throws {
    let root = try #require(buildTree(#"{"s":"hi","n":1e3,"f":0.10,"b":false,"x":null}"#))
    let values = root.children?.map(\.value) ?? []
    #expect(values[0] == .string("hi"))
    #expect(values[1] == .number("1e3")) // lexeme preserved
    #expect(values[2] == .number("0.10"))
    #expect(values[3] == .bool(false))
    #expect(values[4] == .null)
}

@Test func jsonTreeStringEscapes() throws {
    let root = try #require(buildTree(#"{"k":"a\nbA😀"}"#))
    #expect(root.children?.first?.value == .string("a\nbA😀"))
}

@Test func jsonTreeChildCounts() throws {
    let root = try #require(buildTree("[10, 20, 30, 40, 50]"))
    #expect(root.totalChildCount == 5)
    #expect(root.children?.count == 5)
    #expect(root.omittedChildren == 0)
}

@Test func jsonTreeLimitConstants() {
    #expect(JSONTreeLimits.maxDocumentBytes == 2 * 1024 * 1024)
    #expect(JSONTreeLimits.maxNodeCount == 20_000)
    #expect(JSONTreeLimits.maxChildrenPerNode == 1_000)
}

@Test func jsonTreeNodeCountCapTriggersFallback() {
    // Nested arrays so the per-node child cap (1k) cannot keep the total under the node cap.
    let inner = "[" + (0..<JSONTreeLimits.maxChildrenPerNode).map(String.init).joined(separator: ",") + "]"
    let outerCount = JSONTreeLimits.maxNodeCount / JSONTreeLimits.maxChildrenPerNode + 1
    let json = "[" + Array(repeating: inner, count: outerCount).joined(separator: ",") + "]"
    guard case .tooManyNodes = JSONTreeModel.build(jsonString: json) else {
        Issue.record("Expected .tooManyNodes")
        return
    }
}

@Test func jsonTreeDocumentSizeCapTriggersFallback() {
    let big = "{\"a\":\"" + String(repeating: "x", count: JSONTreeLimits.maxDocumentBytes) + "\"}"
    guard case .documentTooLarge = JSONTreeModel.build(jsonString: big) else {
        Issue.record("Expected .documentTooLarge")
        return
    }
}

@Test func jsonTreeChildrenPerNodeCap() throws {
    let json = "[" + (0..<1500).map(String.init).joined(separator: ",") + "]"
    let root = try #require(buildTree(json))
    #expect(root.children?.count == JSONTreeLimits.maxChildrenPerNode)
    #expect(root.omittedChildren == 500)
    #expect(root.totalChildCount == 1500)
}

@Test func jsonTreeInvalidJSON() {
    guard case .invalid = JSONTreeModel.build(jsonString: "{not json") else {
        Issue.record("Expected .invalid")
        return
    }
}

@Test func jsonTreeNodeCount() {
    if case .tree(_, let nodeCount) = JSONTreeModel.build(jsonString: #"{"a":[1,2],"b":3}"#) {
        #expect(nodeCount == 5) // root, a, a[0], a[1], b
    } else {
        Issue.record("Expected .tree")
    }
}

@Test func jsonValuePrettyPrintPreservesOrder() throws {
    let value = try JSONValueParser.parse(#"{"z":[1,{"y":"a\"b"}],"a":null}"#)
    let expected = """
    {
      "z": [
        1,
        {
          "y": "a\\"b"
        }
      ],
      "a": null
    }
    """
    #expect(value.prettyPrinted() == expected)
}

@Test func jsonValueScalarCopyText() {
    #expect(JSONValue.string("hi there").scalarText == "hi there")
    #expect(JSONValue.number("1e3").scalarText == "1e3")
    #expect(JSONValue.bool(true).scalarText == "true")
    #expect(JSONValue.null.scalarText == "null")
    #expect(JSONValue.array([]).scalarText == nil)
}

@Test func jsonParserRejectsTrailingGarbage() {
    #expect(throws: JSONParseError.self) { try JSONValueParser.parse("{} extra") }
}

@Test func jsonParserDepthLimit() {
    let deep = String(repeating: "[", count: 5_000) + String(repeating: "]", count: 5_000)
    #expect(throws: JSONParseError.self) { try JSONValueParser.parse(deep) }
}

// MARK: - Preview kind mapping

@Test func previewKindContentTypeTable() {
    #expect(previewKind(contentType: "text/html", bodyPrefix: Data()) == .html)
    #expect(previewKind(contentType: "text/html; charset=utf-8", bodyPrefix: Data()) == .html)
    #expect(previewKind(contentType: "image/png", bodyPrefix: Data()) == .image)
    #expect(previewKind(contentType: "IMAGE/JPEG", bodyPrefix: Data()) == .image)
    #expect(previewKind(contentType: "image/svg+xml", bodyPrefix: Data()) == .svg)
    #expect(previewKind(contentType: "application/pdf", bodyPrefix: Data()) == .pdf)
    #expect(previewKind(contentType: "audio/mpeg", bodyPrefix: Data()) == .audioVideo)
    #expect(previewKind(contentType: "video/mp4", bodyPrefix: Data()) == .audioVideo)
    #expect(previewKind(contentType: "text/plain", bodyPrefix: Data()) == .text)
    #expect(previewKind(contentType: "application/json", bodyPrefix: Data()) == .text)
    #expect(previewKind(contentType: "application/hal+json", bodyPrefix: Data()) == .text)
    #expect(previewKind(contentType: "application/atom+xml", bodyPrefix: Data()) == .text)
}

@Test func previewKindMagicByteSniffing() {
    let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00])
    let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0])
    let gif = Data("GIF89a".utf8)
    let pdf = Data("%PDF-1.7".utf8)
    var webp = Data("RIFF".utf8); webp.append(Data([0x01, 0x02, 0x03, 0x04])); webp.append(Data("WEBP".utf8))

    #expect(previewKind(contentType: "application/octet-stream", bodyPrefix: png) == .image)
    #expect(previewKind(contentType: nil, bodyPrefix: png) == .image)
    #expect(previewKind(contentType: "application/octet-stream", bodyPrefix: jpeg) == .image)
    #expect(previewKind(contentType: "application/octet-stream", bodyPrefix: gif) == .image)
    #expect(previewKind(contentType: nil, bodyPrefix: webp) == .image)
    #expect(previewKind(contentType: "application/octet-stream", bodyPrefix: pdf) == .pdf)
    #expect(previewKind(contentType: nil, bodyPrefix: Data("plain words".utf8)) == .text)
    #expect(previewKind(contentType: nil, bodyPrefix: Data("<!DOCTYPE html><html>".utf8)) == .html)
    #expect(previewKind(contentType: nil, bodyPrefix: Data("<svg xmlns=\"x\">".utf8)) == .svg)
    #expect(previewKind(contentType: "application/octet-stream", bodyPrefix: Data([0x00, 0x01, 0x02])) == .binary)
    #expect(previewKind(contentType: nil, bodyPrefix: Data([0xC0, 0xC1, 0xFE, 0xFF])) == .binary)
}

// MARK: - Hex dump

@Test func hexDumpFormatting() {
    let (text, truncated) = HexDump.format(Data("Hello World!".utf8))
    #expect(!truncated)
    #expect(text.hasPrefix("00000000  "))
    #expect(text.contains("48 65 6C 6C 6F 20 57 6F  72 6C 64 21"))
    #expect(text.hasSuffix("|Hello World!|"))
}

@Test func hexDumpAlignmentAndAsciiColumn() throws {
    var data = Data("ABCDEFGHIJKLMNOP".utf8) // exactly one full row
    data.append(Data([0x00, 0x7F, 0x41]))    // partial row with non-printables
    let (text, _) = HexDump.format(data)
    let lines = text.split(separator: "\n").map(String.init)
    #expect(lines.count == 2)

    // The ASCII column starts at the same character offset on every line.
    let firstBar = try #require(lines[0].firstIndex(of: "|"))
    let secondBar = try #require(lines[1].firstIndex(of: "|"))
    #expect(lines[0].distance(from: lines[0].startIndex, to: firstBar) == lines[1].distance(from: lines[1].startIndex, to: secondBar))

    #expect(lines[0].hasSuffix("|ABCDEFGHIJKLMNOP|"))
    #expect(lines[1].hasPrefix("00000010  "))
    #expect(lines[1].hasSuffix("|..A|")) // NUL and DEL rendered as dots
}

@Test func hexDumpTruncation() {
    #expect(HexDump.maxBytes == 64 * 1024)
    let big = Data(repeating: 0x41, count: HexDump.maxBytes + 100)
    let (text, truncated) = HexDump.format(big)
    #expect(truncated)
    #expect(text.split(separator: "\n").count == HexDump.maxBytes / HexDump.bytesPerRow)

    let (_, notTruncated) = HexDump.format(Data(repeating: 0x41, count: HexDump.maxBytes))
    #expect(!notTruncated)
}

// MARK: - Filename inference

@Test func filenameRFC5987() {
    let name = ResponseFilename.infer(
        contentDisposition: "attachment; filename*=UTF-8''na%C3%AFve%20file.txt",
        contentType: nil,
        requestURL: nil
    )
    #expect(name == "naïve file.txt")
}

@Test func filenameRFC5987LowercaseCharsetAndPrecedence() {
    // filename*= wins over filename=, charset token is case-insensitive
    let name = ResponseFilename.infer(
        contentDisposition: "attachment; filename=\"fallback.bin\"; filename*=utf-8''pr%C3%A9cis.pdf",
        contentType: nil,
        requestURL: nil
    )
    #expect(name == "précis.pdf")
}

@Test func filenameQuotedWithEscapedQuote() {
    let name = ResponseFilename.infer(
        contentDisposition: #"attachment; filename="a\"b.txt""#,
        contentType: nil,
        requestURL: nil
    )
    #expect(name == "a\"b.txt")
}

@Test func filenameUnquotedToken() {
    let name = ResponseFilename.infer(
        contentDisposition: "attachment; filename=report.pdf; size=100",
        contentType: nil,
        requestURL: nil
    )
    #expect(name == "report.pdf")
}

@Test func filenameURLFallback() {
    let name = ResponseFilename.infer(
        contentDisposition: nil,
        contentType: "text/csv",
        requestURL: "https://example.com/files/data.csv?version=1"
    )
    #expect(name == "data.csv")
}

@Test func filenameExtensionFromMime() {
    #expect(ResponseFilename.infer(contentDisposition: nil, contentType: "application/json", requestURL: "https://example.com/") == "response.json")
    #expect(ResponseFilename.infer(contentDisposition: nil, contentType: "image/png; charset=binary", requestURL: nil) == "response.png")
    #expect(ResponseFilename.infer(contentDisposition: nil, contentType: nil, requestURL: nil) == "response")
}

@Test func filenameSanitization() {
    let traversal = ResponseFilename.infer(
        contentDisposition: "attachment; filename=\"../../etc/passwd\"",
        contentType: nil,
        requestURL: nil
    )
    #expect(!traversal.contains("/"))
    #expect(!traversal.hasPrefix("."))
    #expect(traversal.contains("passwd"))

    #expect(ResponseFilename.sanitize("a/b\\c:d") == "a_b_c_d")
    #expect(ResponseFilename.sanitize("a\u{0}b\u{1F}c.txt") == "abc.txt")

    let long = ResponseFilename.sanitize(String(repeating: "é", count: 300))
    #expect(long.utf8.count <= ResponseFilename.maxFilenameBytes)
    #expect(!long.isEmpty)
}

@Test func filenameSanitizeEmptyFallsBack() {
    #expect(ResponseFilename.infer(contentDisposition: "attachment; filename=\"...\"", contentType: nil, requestURL: nil) == "response")
}

@Test func filenameHeaderLookupCaseInsensitive() {
    let headers = ["content-disposition": "attachment; filename=x.bin"]
    #expect(ResponseFilename.headerValue("Content-Disposition", in: headers) == "attachment; filename=x.bin")
    #expect(ResponseFilename.headerValue("Missing", in: headers) == nil)
}
