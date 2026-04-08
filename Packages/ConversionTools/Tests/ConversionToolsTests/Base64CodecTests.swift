import Testing
import Foundation
@testable import ConversionTools

@Test func base64Encode() { #expect(Base64Codec.encode("Hello, World!") == "SGVsbG8sIFdvcmxkIQ==") }
@Test func base64Decode() { #expect(Base64Codec.decode("SGVsbG8sIFdvcmxkIQ==") == "Hello, World!") }
@Test func base64EncodeEmpty() { #expect(Base64Codec.encode("") == "") }
@Test func base64DecodeInvalid() { #expect(Base64Codec.decode("!!!invalid!!!") == nil) }
@Test func base64URLSafeEncode() {
    let input = "subjects?_d"
    let urlSafe = Base64Codec.encode(input, urlSafe: true)
    #expect(!urlSafe.contains("+"))
    #expect(!urlSafe.contains("/"))
    #expect(Base64Codec.decode(urlSafe, urlSafe: true) == input)
}
@Test func base64EncodeChinese() { let input = "你好世界"; #expect(Base64Codec.decode(Base64Codec.encode(input)) == input) }
@Test func base64EncodeImage() {
    let pngData = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    #expect(Base64Codec.decodeToData(Base64Codec.encodeData(pngData)) == pngData)
}
