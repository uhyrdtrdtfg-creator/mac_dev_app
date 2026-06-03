import Foundation
import CryptoKit
import CCommonCrypto

public enum KDFFunction: String, CaseIterable, Identifiable, Sendable {
    case pbkdf2 = "PBKDF2"
    case hkdf = "HKDF"
    public var id: String { rawValue }
}

public enum KDFHash: String, CaseIterable, Identifiable, Sendable {
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"
    public var id: String { rawValue }

    var ccPRF: CCPseudoRandomAlgorithm {
        switch self {
        case .sha1: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA1)
        case .sha256: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256)
        case .sha512: CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512)
        }
    }
}

public enum KDFOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case hex = "Hex"
    case base64 = "Base64"
    public var id: String { rawValue }
}

public enum KeyDerivationError: Error, LocalizedError {
    case derivationFailed
    case invalidParameters

    public var errorDescription: String? {
        switch self {
        case .derivationFailed: "Key derivation failed"
        case .invalidParameters: "Invalid parameters (length must be 1–1024 bytes)"
        }
    }
}

public enum KeyDerivation {
    /// PBKDF2 password-based key derivation backed by CommonCrypto.
    public static func pbkdf2(password: String, salt: String, iterations: Int, keyLength: Int, hash: KDFHash) throws -> Data {
        guard keyLength > 0, keyLength <= 1024, iterations > 0 else { throw KeyDerivationError.invalidParameters }
        let passwordData = Array(password.utf8)
        let saltData = Array(salt.utf8)
        var derived = [UInt8](repeating: 0, count: keyLength)

        let status = CCKeyDerivationPBKDF(
            CCPBKDFAlgorithm(kCCPBKDF2),
            password, passwordData.count,
            saltData, saltData.count,
            hash.ccPRF,
            UInt32(iterations),
            &derived, keyLength
        )
        guard status == kCCSuccess else { throw KeyDerivationError.derivationFailed }
        return Data(derived)
    }

    /// HKDF (RFC 5869) key derivation backed by CryptoKit.
    public static func hkdf(secret: String, salt: String, info: String, keyLength: Int, hash: KDFHash) throws -> Data {
        guard keyLength > 0, keyLength <= 1024 else { throw KeyDerivationError.invalidParameters }
        let ikm = SymmetricKey(data: Data(secret.utf8))
        let saltData = Data(salt.utf8)
        let infoData = Data(info.utf8)

        let key: SymmetricKey
        switch hash {
        case .sha1:
            key = CryptoKit.HKDF<Insecure.SHA1>.deriveKey(inputKeyMaterial: ikm, salt: saltData, info: infoData, outputByteCount: keyLength)
        case .sha256:
            key = CryptoKit.HKDF<SHA256>.deriveKey(inputKeyMaterial: ikm, salt: saltData, info: infoData, outputByteCount: keyLength)
        case .sha512:
            key = CryptoKit.HKDF<SHA512>.deriveKey(inputKeyMaterial: ikm, salt: saltData, info: infoData, outputByteCount: keyLength)
        }
        return key.withUnsafeBytes { Data($0) }
    }

    public static func format(_ data: Data, as format: KDFOutputFormat) -> String {
        switch format {
        case .hex: data.map { String(format: "%02x", $0) }.joined()
        case .base64: data.base64EncodedString()
        }
    }
}
