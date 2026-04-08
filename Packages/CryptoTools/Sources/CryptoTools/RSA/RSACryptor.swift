import Foundation
import Security

public enum RSAKeyBits: Int, CaseIterable, Identifiable, Sendable {
    case bits1024 = 1024
    case bits2048 = 2048
    case bits4096 = 4096
    public var id: Int { rawValue }
}

public enum RSAPadding: String, CaseIterable, Identifiable, Sendable {
    case pkcs1 = "PKCS1 v1.5"
    case oaepSHA256 = "OAEP SHA-256"
    public var id: String { rawValue }

    var algorithm: SecKeyAlgorithm {
        switch self {
        case .pkcs1: .rsaEncryptionPKCS1
        case .oaepSHA256: .rsaEncryptionOAEPSHA256
        }
    }
    var decryptAlgorithm: SecKeyAlgorithm { algorithm }
}

public enum RSAError: Error, LocalizedError {
    case keyGenerationFailed(OSStatus)
    case invalidPEM
    case encryptionFailed(Error?)
    case decryptionFailed(Error?)
    case keyCreationFailed

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let s): "Key generation failed with status \(s)"
        case .invalidPEM: "Invalid PEM key format"
        case .encryptionFailed(let e): "Encryption failed: \(e?.localizedDescription ?? "unknown")"
        case .decryptionFailed(let e): "Decryption failed: \(e?.localizedDescription ?? "unknown")"
        case .keyCreationFailed: "Failed to create SecKey from PEM"
        }
    }
}

public struct RSAKeyPair: Sendable {
    public let publicKeyPEM: String
    public let privateKeyPEM: String
}

public enum RSACryptor {
    public static func generateKeyPair(bits: Int) throws -> RSAKeyPair {
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits as String: bits]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else { throw RSAError.keyGenerationFailed(-1) }
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else { throw RSAError.keyGenerationFailed(-2) }
        return RSAKeyPair(publicKeyPEM: try exportKeyToPEM(publicKey, isPublic: true), privateKeyPEM: try exportKeyToPEM(privateKey, isPublic: false))
    }

    public static func encrypt(plaintext: String, publicKeyPEM: String, padding: RSAPadding) throws -> Data {
        let key = try secKey(fromPEM: publicKeyPEM, isPublic: true)
        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(key, padding.algorithm, Data(plaintext.utf8) as CFData, &error) else { throw RSAError.encryptionFailed(error?.takeRetainedValue()) }
        return encrypted as Data
    }

    public static func decrypt(ciphertext: Data, privateKeyPEM: String, padding: RSAPadding) throws -> String {
        let key = try secKey(fromPEM: privateKeyPEM, isPublic: false)
        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(key, padding.decryptAlgorithm, ciphertext as CFData, &error) else { throw RSAError.decryptionFailed(error?.takeRetainedValue()) }
        guard let result = String(data: decrypted as Data, encoding: .utf8) else { throw RSAError.decryptionFailed(nil) }
        return result
    }

    private static func exportKeyToPEM(_ key: SecKey, isPublic: Bool) throws -> String {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) else { throw RSAError.keyGenerationFailed(-3) }
        let base64 = (data as Data).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let header = isPublic ? "-----BEGIN PUBLIC KEY-----" : "-----BEGIN RSA PRIVATE KEY-----"
        let footer = isPublic ? "-----END PUBLIC KEY-----" : "-----END RSA PRIVATE KEY-----"
        return "\(header)\n\(base64)\n\(footer)"
    }

    private static func secKey(fromPEM pem: String, isPublic: Bool) throws -> SecKey {
        let header = isPublic ? "-----BEGIN PUBLIC KEY-----" : "-----BEGIN RSA PRIVATE KEY-----"
        let footer = isPublic ? "-----END PUBLIC KEY-----" : "-----END RSA PRIVATE KEY-----"
        let base64 = pem.replacingOccurrences(of: header, with: "").replacingOccurrences(of: footer, with: "").replacingOccurrences(of: "\n", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: base64) else { throw RSAError.invalidPEM }
        let keyClass = isPublic ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate
        let attributes: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeRSA, kSecAttrKeyClass as String: keyClass]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else { throw RSAError.keyCreationFailed }
        return key
    }
}
