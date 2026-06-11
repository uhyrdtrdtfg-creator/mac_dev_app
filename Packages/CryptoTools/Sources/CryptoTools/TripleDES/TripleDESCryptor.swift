import Foundation
import CCommonCrypto

public enum TripleDESMode: String, CaseIterable, Identifiable, Sendable {
    case ecb = "ECB"
    case cbc = "CBC"
    public var id: String { rawValue }
}

public enum TripleDESPadding: String, CaseIterable, Identifiable, Sendable {
    case pkcs7 = "PKCS7"
    case noPadding = "None"
    public var id: String { rawValue }
}

public enum TripleDESError: Error, LocalizedError {
    case invalidKeySize
    case invalidIVSize
    case encryptionFailed(status: Int32)
    case decryptionFailed(status: Int32)
    case missingIV

    public var errorDescription: String? {
        switch self {
        case .invalidKeySize: "Invalid key size. Must be 24 bytes."
        case .invalidIVSize: "Invalid IV size. Must be 8 bytes."
        case .encryptionFailed(let s): "Encryption failed with status \(s)"
        case .decryptionFailed(let s): "Decryption failed with status \(s)"
        case .missingIV: "IV is required for CBC mode."
        }
    }
}

public struct TripleDESResult: Sendable {
    public let ciphertext: Data
    public let iv: Data?
}

public enum TripleDESCryptor {
    public static func generateRandomKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: kCCKeySize3DES)
        _ = SecRandomCopyBytes(kSecRandomDefault, kCCKeySize3DES, &bytes)
        return Data(bytes)
    }

    public static func generateRandomIV() -> Data {
        var bytes = [UInt8](repeating: 0, count: kCCBlockSize3DES)
        _ = SecRandomCopyBytes(kSecRandomDefault, kCCBlockSize3DES, &bytes)
        return Data(bytes)
    }

    public static func encrypt(plaintext: String, key: Data, mode: TripleDESMode, iv: Data? = nil, padding: TripleDESPadding = .pkcs7) throws -> TripleDESResult {
        try encrypt(data: Data(plaintext.utf8), key: key, mode: mode, iv: iv, padding: padding)
    }

    public static func encrypt(data: Data, key: Data, mode: TripleDESMode, iv: Data? = nil, padding: TripleDESPadding = .pkcs7) throws -> TripleDESResult {
        guard key.count == kCCKeySize3DES else { throw TripleDESError.invalidKeySize }
        switch mode {
        case .cbc:
            guard let iv else { throw TripleDESError.missingIV }
            guard iv.count == kCCBlockSize3DES else { throw TripleDESError.invalidIVSize }
            return try crypt(operation: CCOperation(kCCEncrypt), data: data, key: key, iv: iv, ecb: false, padding: padding)
        case .ecb:
            return try crypt(operation: CCOperation(kCCEncrypt), data: data, key: key, iv: Data(repeating: 0, count: kCCBlockSize3DES), ecb: true, padding: padding)
        }
    }

    public static func decrypt(ciphertext: Data, key: Data, mode: TripleDESMode, iv: Data? = nil, padding: TripleDESPadding = .pkcs7) throws -> String {
        guard key.count == kCCKeySize3DES else { throw TripleDESError.invalidKeySize }
        let decryptedData: Data
        switch mode {
        case .cbc:
            guard let iv else { throw TripleDESError.missingIV }
            guard iv.count == kCCBlockSize3DES else { throw TripleDESError.invalidIVSize }
            decryptedData = try crypt(operation: CCOperation(kCCDecrypt), data: ciphertext, key: key, iv: iv, ecb: false, padding: padding).ciphertext
        case .ecb:
            decryptedData = try crypt(operation: CCOperation(kCCDecrypt), data: ciphertext, key: key, iv: Data(repeating: 0, count: kCCBlockSize3DES), ecb: true, padding: padding).ciphertext
        }
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            return decryptedData.base64EncodedString()
        }
        return result
    }

    private static func crypt(operation: CCOperation, data: Data, key: Data, iv: Data, ecb: Bool, padding: TripleDESPadding) throws -> TripleDESResult {
        let options: UInt32 = {
            var opts: UInt32 = 0
            if ecb { opts |= UInt32(kCCOptionECBMode) }
            if padding == .pkcs7 { opts |= UInt32(kCCOptionPKCS7Padding) }
            return opts
        }()
        let bufferSize = data.count + kCCBlockSize3DES
        var buffer = Data(count: bufferSize)
        var bytesProcessed = 0
        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(operation, CCAlgorithm(kCCAlgorithm3DES), CCOptions(options),
                                keyPtr.baseAddress, key.count, ivPtr.baseAddress,
                                dataPtr.baseAddress, data.count, bufferPtr.baseAddress, bufferSize, &bytesProcessed)
                    }
                }
            }
        }
        guard status == kCCSuccess else {
            if operation == CCOperation(kCCEncrypt) { throw TripleDESError.encryptionFailed(status: status) }
            throw TripleDESError.decryptionFailed(status: status)
        }
        buffer.count = bytesProcessed
        return TripleDESResult(ciphertext: buffer, iv: ecb ? nil : iv)
    }
}
