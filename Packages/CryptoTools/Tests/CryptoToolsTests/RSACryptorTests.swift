import Testing
import Foundation
@testable import CryptoTools

@Test func rsaKeyGeneration2048() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    #expect(!keyPair.publicKeyPEM.isEmpty)
    #expect(!keyPair.privateKeyPEM.isEmpty)
    #expect(keyPair.publicKeyPEM.hasPrefix("-----BEGIN PUBLIC KEY-----"))
    #expect(keyPair.privateKeyPEM.hasPrefix("-----BEGIN RSA PRIVATE KEY-----"))
}

@Test func rsaEncryptDecryptRoundTrip() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let plaintext = "Hello, RSA!"
    let encrypted = try RSACryptor.encrypt(plaintext: plaintext, publicKeyPEM: keyPair.publicKeyPEM, padding: .oaepSHA256)
    #expect(!encrypted.isEmpty)
    let decrypted = try RSACryptor.decrypt(ciphertext: encrypted, privateKeyPEM: keyPair.privateKeyPEM, padding: .oaepSHA256)
    #expect(decrypted == plaintext)
}

@Test func rsaEncryptDecryptPKCS1() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let plaintext = "Test PKCS1"
    let encrypted = try RSACryptor.encrypt(plaintext: plaintext, publicKeyPEM: keyPair.publicKeyPEM, padding: .pkcs1)
    let decrypted = try RSACryptor.decrypt(ciphertext: encrypted, privateKeyPEM: keyPair.privateKeyPEM, padding: .pkcs1)
    #expect(decrypted == plaintext)
}

@Test func rsaSignVerifyRoundTrip() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let message = "Sign me"
    for algorithm in RSASignatureAlgorithm.allCases {
        let signature = try RSACryptor.sign(message: message, privateKeyPEM: keyPair.privateKeyPEM, algorithm: algorithm)
        #expect(signature.count == 256)
        #expect(try RSACryptor.verify(message: message, signature: signature, publicKeyPEM: keyPair.publicKeyPEM, algorithm: algorithm))
    }
}

@Test func rsaVerifyRejectsTamperedMessage() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let signature = try RSACryptor.sign(message: "original", privateKeyPEM: keyPair.privateKeyPEM, algorithm: .sha256)
    #expect(try !RSACryptor.verify(message: "tampered", signature: signature, publicKeyPEM: keyPair.publicKeyPEM, algorithm: .sha256))
}

@Test func rsaVerifyRejectsWrongKey() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let otherPair = try RSACryptor.generateKeyPair(bits: 2048)
    let signature = try RSACryptor.sign(message: "msg", privateKeyPEM: keyPair.privateKeyPEM, algorithm: .sha512)
    #expect(try !RSACryptor.verify(message: "msg", signature: signature, publicKeyPEM: otherPair.publicKeyPEM, algorithm: .sha512))
}

@Test func rsaInvalidKeyThrows() {
    #expect(throws: RSAError.self) {
        try RSACryptor.encrypt(plaintext: "test", publicKeyPEM: "not-a-key", padding: .oaepSHA256)
    }
}
