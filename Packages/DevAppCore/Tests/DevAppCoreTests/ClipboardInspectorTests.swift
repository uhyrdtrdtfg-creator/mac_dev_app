import Testing
@testable import DevAppCore

private func firstKind(_ s: String) -> ClipboardSuggestion.Kind? {
    ClipboardInspector.detect(s).first?.kind
}

private func kinds(_ s: String) -> Set<ClipboardSuggestion.Kind> {
    Set(ClipboardInspector.detect(s).map(\.kind))
}

@Test func emptyOrBlankYieldsNothing() {
    #expect(ClipboardInspector.detect("").isEmpty)
    #expect(ClipboardInspector.detect("   \n\t ").isEmpty)
}

@Test func detectsJSONObjectAndArray() {
    #expect(firstKind(#"{"a":1,"b":[2,3]}"#) == .json)
    #expect(firstKind("[1, 2, 3]") == .json)
    #expect(ClipboardInspector.detect(#"{"a":1}"#).first?.toolID == "json-formatter")
    // Not JSON.
    #expect(firstKind("{not json") == nil)
    #expect(firstKind("hello world") == nil)
}

@Test func detectsJWTBeforeBase64() {
    // header.payload.signature, header starts with eyJ
    let jwt = "eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ.abc123_-"
    #expect(firstKind(jwt) == .jwt)
    #expect(kinds(jwt).contains(.base64) == false) // JWT wins, base64 suppressed
    // Two segments only → not a JWT.
    #expect(firstKind("eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjMifQ") != .jwt)
}

@Test func detectsUUID() {
    #expect(kinds("123E4567-E89B-12D3-A456-426614174000").contains(.uuid))
    #expect(kinds("not-a-uuid").contains(.uuid) == false)
}

@Test func detectsURL() {
    #expect(kinds("https://example.com/path?q=1").contains(.url))
    #expect(kinds("http://localhost:8080").contains(.url))
    // Percent-encoded fragment without a scheme still routes to the URL codec.
    #expect(kinds("name%3Dvalue%26x%3D1").contains(.url))
    #expect(kinds("just text").contains(.url) == false)
}

@Test func detectsColorOnlyWithHashOrFunction() {
    #expect(kinds("#FF8800").contains(.color))
    #expect(kinds("#abcd").contains(.color))
    #expect(kinds("rgb(255, 136, 0)").contains(.color))
    // Bare hex without '#' is hex bytes, not a color.
    #expect(kinds("FF8800").contains(.color) == false)
}

@Test func detectsTimestampAndSuppressesHex() {
    let ks = kinds("1700000000") // 10-digit epoch seconds
    #expect(ks.contains(.timestamp))
    #expect(ks.contains(.hex) == false)
    #expect(kinds("1700000000000").contains(.timestamp)) // 13-digit ms
    #expect(kinds("123").contains(.timestamp) == false)  // too short
}

@Test func detectsHexBytes() {
    #expect(kinds("48656c6c6f").contains(.hex))   // "Hello"
    #expect(kinds("0xDEADBEEF").contains(.hex))
    #expect(kinds("abc").contains(.hex) == false) // odd length
}

@Test func detectsBase64AsFallback() {
    // "Hello, world" base64, not valid as anything more specific.
    #expect(firstKind("SGVsbG8sIHdvcmxk") == .base64)
    // Short strings are not flagged.
    #expect(kinds("dGVzdA==").contains(.base64)) // "test" → valid 8-char base64
    #expect(kinds("ab").contains(.base64) == false)
}
