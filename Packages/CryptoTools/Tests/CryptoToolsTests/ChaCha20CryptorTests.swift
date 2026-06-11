import Testing
import Foundation
import DevAppCore
@testable import CryptoTools

@Test func chacha20EncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = ChaCha20Cryptor.generateRandomKey()
    let encrypted = try ChaCha20Cryptor.encrypt(plaintext: plaintext, key: key)
    let decrypted = try ChaCha20Cryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, nonce: encrypted.nonce, tag: encrypted.tag)
    #expect(decrypted == plaintext)
}

@Test func chacha20DecryptWithTamperedTagThrows() throws {
    let key = ChaCha20Cryptor.generateRandomKey()
    let encrypted = try ChaCha20Cryptor.encrypt(plaintext: "secret message", key: key)
    var tamperedTag = Data(encrypted.tag)
    tamperedTag[tamperedTag.startIndex] ^= 0xff
    #expect(throws: ChaCha20Error.self) {
        try ChaCha20Cryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, nonce: encrypted.nonce, tag: tamperedTag)
    }
}

@Test func chacha20DecryptWithWrongKeyThrows() throws {
    let key = ChaCha20Cryptor.generateRandomKey()
    let wrongKey = ChaCha20Cryptor.generateRandomKey()
    let encrypted = try ChaCha20Cryptor.encrypt(plaintext: "secret message", key: key)
    #expect(throws: ChaCha20Error.self) {
        try ChaCha20Cryptor.decrypt(ciphertext: encrypted.ciphertext, key: wrongKey, nonce: encrypted.nonce, tag: encrypted.tag)
    }
}

@Test func chacha20RFC8439KnownAnswer() throws {
    let key = try #require(Data(hexString: "808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f"))
    let nonce = try #require(Data(hexString: "070000004041424344454647"))
    let plaintext = "Ladies and Gentlemen of the class of '99: If I could offer you only one tip for the future, sunscreen would be it."
    let expectedCiphertext = try #require(Data(hexString: """
        d31a8d34648e60db7b86afbc53ef7ec2a4aded51296e08fea9e2b5a736ee62d6\
        3dbea45e8ca9671282fafb69da92728b1a71de0a9e060b2905d6a5b67ecd3b36\
        92ddbd7f2d778b8c9803aee328091b58fab324e4fad675945585808b4831d7bc\
        3ff4def08e4b7a9de576d26586cec64b6116
        """))
    let encrypted = try ChaCha20Cryptor.encrypt(plaintext: plaintext, key: key, nonce: nonce)
    #expect(encrypted.ciphertext == expectedCiphertext)
    #expect(encrypted.ciphertext.count == plaintext.utf8.count)
    #expect(encrypted.nonce == nonce)
    #expect(encrypted.tag.count == 16)
    let decrypted = try ChaCha20Cryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, nonce: nonce, tag: encrypted.tag)
    #expect(decrypted == plaintext)
}

@Test func chacha20KeyGeneration() {
    let key = ChaCha20Cryptor.generateRandomKey()
    #expect(key.count == 32)
}

@Test func chacha20NonceGeneration() {
    let nonce = ChaCha20Cryptor.generateRandomNonce()
    #expect(nonce.count == 12)
}

@Test func chacha20InvalidKeySizeThrows() {
    let key = Data(repeating: 0, count: 16)
    #expect(throws: ChaCha20Error.self) {
        try ChaCha20Cryptor.encrypt(plaintext: "test", key: key)
    }
}

@Test func chacha20InvalidNonceSizeThrows() {
    let key = ChaCha20Cryptor.generateRandomKey()
    let nonce = Data(repeating: 0, count: 8)
    #expect(throws: ChaCha20Error.self) {
        try ChaCha20Cryptor.encrypt(plaintext: "test", key: key, nonce: nonce)
    }
}
