import Testing
import Foundation
@testable import CryptoTools

@Test func aesGCMEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World!"
    let key = AESCryptor.generateRandomKey(bits: 256)
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .gcm)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .gcm, iv: encrypted.iv, tag: encrypted.tag)
    #expect(decrypted == plaintext)
}

@Test func aesCBCEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 256)
    let iv = AESCryptor.generateRandomIV()
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .cbc, iv: iv, padding: .pkcs7)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .cbc, iv: iv, padding: .pkcs7)
    #expect(decrypted == plaintext)
}

@Test func aesECBEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 128)
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ecb, padding: .pkcs7)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ecb, padding: .pkcs7)
    #expect(decrypted == plaintext)
}

@Test func aesKeyGeneration128() {
    let key = AESCryptor.generateRandomKey(bits: 128)
    #expect(key.count == 16)
}

@Test func aesKeyGeneration256() {
    let key = AESCryptor.generateRandomKey(bits: 256)
    #expect(key.count == 32)
}

@Test func aesIVGeneration() {
    let iv = AESCryptor.generateRandomIV()
    #expect(iv.count == 16)
}

@Test func aesInvalidKeySize() {
    let key = Data(repeating: 0, count: 15)
    #expect(throws: AESError.self) {
        try AESCryptor.encrypt(plaintext: "test", key: key, mode: .cbc)
    }
}

@Test func aesCTREncryptDecryptRoundTrip128() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 128)
    let iv = AESCryptor.generateRandomIV()
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ctr, iv: iv)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ctr, iv: iv)
    #expect(decrypted == plaintext)
}

@Test func aesCTREncryptDecryptRoundTrip256() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 256)
    let iv = AESCryptor.generateRandomIV()
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ctr, iv: iv)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ctr, iv: iv)
    #expect(decrypted == plaintext)
}

@Test func aesCTRNoPadding() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 256)
    let iv = AESCryptor.generateRandomIV()
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ctr, iv: iv)
    #expect(encrypted.ciphertext.count == plaintext.utf8.count)
}

@Test func aesCTRWrongIVProducesDifferentPlaintext() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 256)
    let iv = AESCryptor.generateRandomIV()
    var wrongIVBytes = [UInt8](iv)
    wrongIVBytes[0] ^= 0xFF
    let wrongIV = Data(wrongIVBytes)
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .ctr, iv: iv)
    let decrypted = try AESCryptor.decrypt(ciphertext: encrypted.ciphertext, key: key, mode: .ctr, iv: wrongIV)
    #expect(decrypted != plaintext)
}

@Test func aesCTRMissingIV() {
    let key = AESCryptor.generateRandomKey(bits: 128)
    #expect(throws: AESError.self) {
        try AESCryptor.encrypt(plaintext: "test", key: key, mode: .ctr)
    }
}

@Test func aesCTRInvalidIVSize() {
    let key = AESCryptor.generateRandomKey(bits: 128)
    let iv = Data(repeating: 0, count: 12)
    #expect(throws: AESError.self) {
        try AESCryptor.encrypt(plaintext: "test", key: key, mode: .ctr, iv: iv)
    }
}

@Test func aesCTRNISTVector() throws {
    let key = try #require(Data(hexString: "2b7e151628aed2a6abf7158809cf4f3c"))
    let counter = try #require(Data(hexString: "f0f1f2f3f4f5f6f7f8f9fafbfcfdfeff"))
    let plaintext = try #require(Data(hexString: "6bc1bee22e409f96e93d7e117393172a"))
    let expected = try #require(Data(hexString: "874d6191b620e3261bef6864990db6ce"))
    let encrypted = try AESCryptor.encrypt(data: plaintext, key: key, mode: .ctr, iv: counter)
    #expect(encrypted.ciphertext == expected)
}

@Test func aesOutputNotEmpty() throws {
    let plaintext = "Hello"
    let key = AESCryptor.generateRandomKey(bits: 256)
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .gcm)
    #expect(!encrypted.ciphertext.isEmpty)
}
