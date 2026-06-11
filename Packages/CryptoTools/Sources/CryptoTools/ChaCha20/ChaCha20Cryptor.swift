import Foundation
import CryptoKit

public enum ChaCha20Error: Error, LocalizedError {
    case invalidKeySize
    case invalidNonceSize
    case invalidTagSize
    case operationFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidKeySize: "Invalid key size. Must be 32 bytes."
        case .invalidNonceSize: "Invalid nonce size. Must be 12 bytes."
        case .invalidTagSize: "Invalid tag size. Must be 16 bytes."
        case .operationFailed(let e): "ChaCha20-Poly1305 operation failed: \(e.localizedDescription)"
        }
    }
}

public struct ChaCha20Result: Sendable {
    public let ciphertext: Data
    public let nonce: Data
    public let tag: Data
}

public enum ChaCha20Cryptor {
    public static func generateRandomKey() -> Data {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, 32, &bytes)
        return Data(bytes)
    }

    public static func generateRandomNonce() -> Data {
        var bytes = [UInt8](repeating: 0, count: 12)
        _ = SecRandomCopyBytes(kSecRandomDefault, 12, &bytes)
        return Data(bytes)
    }

    public static func encrypt(plaintext: String, key: Data, nonce: Data? = nil) throws -> ChaCha20Result {
        try encrypt(data: Data(plaintext.utf8), key: key, nonce: nonce)
    }

    public static func encrypt(data: Data, key: Data, nonce: Data? = nil) throws -> ChaCha20Result {
        guard key.count == 32 else { throw ChaCha20Error.invalidKeySize }
        let nonceData = nonce ?? generateRandomNonce()
        guard nonceData.count == 12 else { throw ChaCha20Error.invalidNonceSize }
        do {
            let symmetricKey = SymmetricKey(data: key)
            let chachaNonce = try ChaChaPoly.Nonce(data: nonceData)
            let sealedBox = try ChaChaPoly.seal(data, using: symmetricKey, nonce: chachaNonce)
            return ChaCha20Result(ciphertext: sealedBox.ciphertext, nonce: Data(sealedBox.nonce), tag: sealedBox.tag)
        } catch { throw ChaCha20Error.operationFailed(underlying: error) }
    }

    public static func decrypt(ciphertext: Data, key: Data, nonce: Data, tag: Data) throws -> String {
        guard key.count == 32 else { throw ChaCha20Error.invalidKeySize }
        guard nonce.count == 12 else { throw ChaCha20Error.invalidNonceSize }
        guard tag.count == 16 else { throw ChaCha20Error.invalidTagSize }
        let decryptedData: Data
        do {
            let symmetricKey = SymmetricKey(data: key)
            let chachaNonce = try ChaChaPoly.Nonce(data: nonce)
            let sealedBox = try ChaChaPoly.SealedBox(nonce: chachaNonce, ciphertext: ciphertext, tag: tag)
            decryptedData = try ChaChaPoly.open(sealedBox, using: symmetricKey)
        } catch { throw ChaCha20Error.operationFailed(underlying: error) }
        guard let result = String(data: decryptedData, encoding: .utf8) else {
            return decryptedData.base64EncodedString()
        }
        return result
    }
}
