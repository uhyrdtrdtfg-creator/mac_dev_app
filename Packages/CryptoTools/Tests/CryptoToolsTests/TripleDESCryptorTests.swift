import Testing
import Foundation
import DevAppCore
@testable import CryptoTools

@Test func tripleDESECBEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = TripleDESCryptor.generateRandomKey()
    let encrypted = try TripleDESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ecb, padding: .pkcs7)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ecb, padding: .pkcs7)
    #expect(decrypted == plaintext)
}

@Test func tripleDESCBCEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = TripleDESCryptor.generateRandomKey()
    let iv = TripleDESCryptor.generateRandomIV()
    let encrypted = try TripleDESCryptor.encrypt(plaintext: plaintext, key: key, mode: .cbc, iv: iv, padding: .pkcs7)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .cbc, iv: iv, padding: .pkcs7)
    #expect(decrypted == plaintext)
}

@Test func tripleDESECBNoPaddingKnownBlock() throws {
    let key = try #require(Data(hexString: "0123456789abcdef23456789abcdef01456789abcdef0123"))
    let plaintext = try #require(Data(hexString: "6bc1bee22e409f96"))
    let encrypted = try TripleDESCryptor.encrypt(data: plaintext, key: key, mode: .ecb, padding: .noPadding)
    #expect(encrypted.ciphertext.count == 8)
    #expect(encrypted.ciphertext != plaintext)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ecb, padding: .noPadding)
    #expect(decrypted == plaintext.base64EncodedString())
}

@Test func tripleDESWrongKeyDoesNotRecoverPlaintext() throws {
    let plaintext = "Sensitive legacy payload"
    let key = TripleDESCryptor.generateRandomKey()
    let wrongKey = TripleDESCryptor.generateRandomKey()
    let iv = TripleDESCryptor.generateRandomIV()
    let encrypted = try TripleDESCryptor.encrypt(plaintext: plaintext, key: key, mode: .cbc, iv: iv, padding: .pkcs7)
    do {
        let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: wrongKey, mode: .cbc, iv: iv, padding: .pkcs7)
        #expect(decrypted != plaintext)
    } catch {
        #expect(error is TripleDESError)
    }
}

@Test func tripleDESKeyGeneration() {
    let key = TripleDESCryptor.generateRandomKey()
    #expect(key.count == 24)
}

@Test func tripleDESIVGeneration() {
    let iv = TripleDESCryptor.generateRandomIV()
    #expect(iv.count == 8)
}

@Test func tripleDESInvalidKeySize() {
    let key = Data(repeating: 0, count: 16)
    #expect(throws: TripleDESError.self) {
        try TripleDESCryptor.encrypt(plaintext: "test", key: key, mode: .ecb)
    }
}

@Test func tripleDESMissingIVForCBC() {
    let key = Data(repeating: 0, count: 24)
    #expect(throws: TripleDESError.self) {
        try TripleDESCryptor.encrypt(plaintext: "test", key: key, mode: .cbc)
    }
}

@Test func desECBEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = TripleDESCryptor.generateRandomKey(algorithm: .des)
    let encrypted = try TripleDESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ecb, padding: .pkcs7, algorithm: .des)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ecb, padding: .pkcs7, algorithm: .des)
    #expect(decrypted == plaintext)
}

@Test func desCBCEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = TripleDESCryptor.generateRandomKey(algorithm: .des)
    let iv = TripleDESCryptor.generateRandomIV()
    let encrypted = try TripleDESCryptor.encrypt(plaintext: plaintext, key: key, mode: .cbc, iv: iv, padding: .pkcs7, algorithm: .des)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .cbc, iv: iv, padding: .pkcs7, algorithm: .des)
    #expect(decrypted == plaintext)
}

@Test func desECBNoPaddingKnownAnswerVector() throws {
    let key = try #require(Data(hexString: "133457799bbcdff1"))
    let plaintext = try #require(Data(hexString: "0123456789abcdef"))
    let expected = try #require(Data(hexString: "85e813540f0ab405"))
    let encrypted = try TripleDESCryptor.encrypt(data: plaintext, key: key, mode: .ecb, padding: .noPadding, algorithm: .des)
    #expect(encrypted.ciphertext == expected)
    let decrypted = try TripleDESCryptor.decrypt(ciphertext: expected, key: key, mode: .ecb, padding: .noPadding, algorithm: .des)
    #expect(decrypted == plaintext.base64EncodedString())
}

@Test func desKeyGeneration() {
    let key = TripleDESCryptor.generateRandomKey(algorithm: .des)
    #expect(key.count == 8)
}

@Test func desInvalidKeySize() {
    let key = Data(repeating: 0, count: 16)
    #expect(throws: TripleDESError.self) {
        try TripleDESCryptor.encrypt(plaintext: "test", key: key, mode: .ecb, algorithm: .des)
    }
}
