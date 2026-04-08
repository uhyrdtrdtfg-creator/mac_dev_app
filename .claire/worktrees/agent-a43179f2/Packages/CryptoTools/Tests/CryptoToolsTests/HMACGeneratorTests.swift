import Testing
import Foundation
@testable import CryptoTools

@Test func hmacMD5() {
    let result = HMACGenerator.generate(
        message: "Hi There",
        key: Data(repeating: 0x0b, count: 16),
        algorithm: .md5
    )
    #expect(result == "9294727a3638bb1c13f48ef8158bfc9d")
}

@Test func hmacSHA256() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha256
    )
    #expect(result == "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
}

@Test func hmacSHA512WithStringKey() {
    let result = HMACGenerator.generate(
        message: "Hello",
        keyString: "secret",
        algorithm: .sha512
    )
    #expect(!result.isEmpty)
    #expect(result.count == 128)
}

@Test func hmacSHA1() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha1
    )
    #expect(result == "de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9")
}

@Test func hmacOutputBase64() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha256,
        outputFormat: .base64
    )
    #expect(result == "97yD9DAzhCSxMpjmqm+xQ+9NWaFJRhdZl0edvC0aPNg=")
}
