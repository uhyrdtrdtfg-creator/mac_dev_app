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

@Test func aesOutputNotEmpty() throws {
    let plaintext = "Hello"
    let key = AESCryptor.generateRandomKey(bits: 256)
    let encrypted = try AESCryptor.encrypt(plaintext: plaintext, key: key, mode: .gcm)
    #expect(!encrypted.ciphertext.isEmpty)
}
