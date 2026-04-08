import Foundation
import CryptoKit
import CCommonCrypto

public enum AESMode: String, CaseIterable, Identifiable, Sendable {
    case ecb = "ECB"
    case cbc = "CBC"
    case gcm = "GCM"
    public var id: String { rawValue }
}

public enum AESPadding: String, CaseIterable, Identifiable, Sendable {
    case pkcs7 = "PKCS7"
    case noPadding = "None"
    public var id: String { rawValue }
}

public enum AESKeyBits: Int, CaseIterable, Identifiable, Sendable {
    case bits128 = 128
    case bits192 = 192
    case bits256 = 256
    public var id: Int { rawValue }
    public var byteCount: Int { rawValue / 8 }
}

public enum AESError: Error, LocalizedError {
    case invalidKeySize
    case invalidIVSize
    case encryptionFailed(status: Int32)
    case decryptionFailed(status: Int32)
    case missingIV
    case missingTag
    case gcmFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidKeySize: "Invalid key size. Must be 16, 24, or 32 bytes."
        case .invalidIVSize: "Invalid IV size. Must be 16 bytes for CBC, 12 bytes for GCM."
        case .encryptionFailed(let s): "Encryption failed with status \(s)"
        case .decryptionFailed(let s): "Decryption failed with status \(s)"
        case .missingIV: "IV is required for CBC and GCM modes."
        case .missingTag: "Authentication tag is required for GCM decryption."
        case .gcmFailed(let e): "GCM operation failed: \(e.localizedDescription)"
        }
    }
}

public struct AESResult: Sendable {
    public let ciphertext: Data
    public let iv: Data?
    public let tag: Data?
}

public enum AESCryptor {
    public static func generateRandomKey(bits: Int) -> Data {
        let byteCount = bits / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }

    public static func generateRandomIV(byteCount: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }

    public static func encrypt(plaintext: String, key: Data, mode: AESMode, iv: Data? = nil, padding: AESPadding = .pkcs7) throws -> AESResult {
        try encrypt(data: Data(plaintext.utf8), key: key, mode: mode, iv: iv, padding: padding)
    }

    public static func encrypt(data: Data, key: Data, mode: AESMode, iv: Data? = nil, padding: AESPadding = .pkcs7) throws -> AESResult {
        guard [16, 24, 32].contains(key.count) else { throw AESError.invalidKeySize }
        switch mode {
        case .gcm: return try encryptGCM(data: data, key: key)
        case .cbc:
            guard let iv else { throw AESError.missingIV }
            guard iv.count == 16 else { throw AESError.invalidIVSize }
            return try encryptCommonCrypto(data: data, key: key, iv: iv, ecb: false, padding: padding)
        case .ecb:
            return try encryptCommonCrypto(data: data, key: key, iv: Data(repeating: 0, count: 16), ecb: true, padding: padding)
        }
    }

    public static func decrypt(ciphertext: Data, key: Data, mode: AESMode, iv: Data? = nil, padding: AESPadding = .pkcs7, tag: Data? = nil) throws -> String {
        guard [16, 24, 32].contains(key.count) else { throw AESError.invalidKeySize }
        let decryptedData: Data
        switch mode {
        case .gcm:
            guard let iv else { throw AESError.missingIV }
            guard let tag else { throw AESError.missingTag }
            decryptedData = try decryptGCM(ciphertext: ciphertext, key: key, iv: iv, tag: tag)
        case .cbc:
            guard let iv else { throw AESError.missingIV }
            guard iv.count == 16 else { throw AESError.invalidIVSize }
            decryptedData = try decryptCommonCrypto(data: ciphertext, key: key, iv: iv, ecb: false, padding: padding)
        case .ecb:
            decryptedData = try decryptCommonCrypto(data: ciphertext, key: key, iv: Data(repeating: 0, count: 16), ecb: true, padding: padding)
        }
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            return decryptedData.base64EncodedString()
        }
        return result
    }

    private static func encryptGCM(data: Data, key: Data) throws -> AESResult {
        do {
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return AESResult(ciphertext: sealedBox.ciphertext, iv: Data(sealedBox.nonce), tag: sealedBox.tag)
        } catch { throw AESError.gcmFailed(underlying: error) }
    }

    private static func decryptGCM(ciphertext: Data, key: Data, iv: Data, tag: Data) throws -> Data {
        do {
            let symmetricKey = SymmetricKey(data: key)
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch { throw AESError.gcmFailed(underlying: error) }
    }

    private static func encryptCommonCrypto(data: Data, key: Data, iv: Data, ecb: Bool, padding: AESPadding) throws -> AESResult {
        let options: UInt32 = {
            var opts: UInt32 = 0
            if ecb { opts |= UInt32(kCCOptionECBMode) }
            if padding == .pkcs7 { opts |= UInt32(kCCOptionPKCS7Padding) }
            return opts
        }()
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesEncrypted = 0
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(options),
                                keyPtr.baseAddress, key.count, ivPtr.baseAddress,
                                dataPtr.baseAddress, data.count, bufferPtr.baseAddress, bufferSize, &bytesEncrypted)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw AESError.encryptionFailed(status: status) }
        buffer.count = bytesEncrypted
        return AESResult(ciphertext: buffer, iv: ecb ? nil : iv, tag: nil)
    }

    private static func decryptCommonCrypto(data: Data, key: Data, iv: Data, ecb: Bool, padding: AESPadding) throws -> Data {
        let options: UInt32 = {
            var opts: UInt32 = 0
            if ecb { opts |= UInt32(kCCOptionECBMode) }
            if padding == .pkcs7 { opts |= UInt32(kCCOptionPKCS7Padding) }
            return opts
        }()
        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesDecrypted = 0
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(options),
                                keyPtr.baseAddress, key.count, ivPtr.baseAddress,
                                dataPtr.baseAddress, data.count, bufferPtr.baseAddress, bufferSize, &bytesDecrypted)
                    }
                }
            }
        }
        guard status == kCCSuccess else { throw AESError.decryptionFailed(status: status) }
        buffer.count = bytesDecrypted
        return buffer
    }
}
