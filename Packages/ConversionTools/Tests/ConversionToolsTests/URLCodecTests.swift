import Testing
import Foundation
@testable import ConversionTools

@Test func urlEncodeRFC3986() { #expect(URLCodec.encode("hello world&foo=bar", standard: .rfc3986) == "hello%20world%26foo%3Dbar") }
@Test func urlEncodeFormData() { #expect(URLCodec.encode("hello world&foo=bar", standard: .formData) == "hello+world%26foo%3Dbar") }
@Test func urlDecode() { #expect(URLCodec.decode("hello%20world%26foo%3Dbar") == "hello world&foo=bar") }
@Test func urlDecodeFormData() { #expect(URLCodec.decode("hello+world") == "hello world") }
@Test func urlEncodeChinese() { #expect(URLCodec.encode("你好", standard: .rfc3986) == "%E4%BD%A0%E5%A5%BD") }
@Test func urlDecodeChinese() { #expect(URLCodec.decode("%E4%BD%A0%E5%A5%BD") == "你好") }
@Test func urlParseComponents() {
    let c = URLCodec.parse("https://user:pass@example.com:8080/path/to?key=value&a=b#section")
    #expect(c?.scheme == "https"); #expect(c?.host == "example.com"); #expect(c?.port == 8080)
    #expect(c?.path == "/path/to"); #expect(c?.queryItems?.count == 2); #expect(c?.fragment == "section")
}
@Test func urlParseNil() { #expect(URLCodec.parse("") == nil) }
