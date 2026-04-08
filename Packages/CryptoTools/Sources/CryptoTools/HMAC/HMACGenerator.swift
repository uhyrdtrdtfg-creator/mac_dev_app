import Foundation
import CryptoKit

public enum HMACAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case md5 = "HMAC-MD5"
    case sha1 = "HMAC-SHA1"
    case sha256 = "HMAC-SHA256"
    case sha512 = "HMAC-SHA512"

    public var id: String { rawValue }
}

public enum HMACOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case hex = "Hex"
    case base64 = "Base64"

    public var id: String { rawValue }
}

public enum HMACGenerator {
    public static func generate(
        message: String,
        keyString: String,
        algorithm: HMACAlgorithm,
        outputFormat: HMACOutputFormat = .hex
    ) -> String {
        generate(message: message, key: Data(keyString.utf8), algorithm: algorithm, outputFormat: outputFormat)
    }

    public static func generate(
        message: String,
        key: Data,
        algorithm: HMACAlgorithm,
        outputFormat: HMACOutputFormat = .hex
    ) -> String {
        let messageData = Data(message.utf8)
        let symmetricKey = SymmetricKey(data: key)
        let authData: Data

        switch algorithm {
        case .md5:
            let auth = CryptoKit.HMAC<Insecure.MD5>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha1:
            let auth = CryptoKit.HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha256:
            let auth = CryptoKit.HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha512:
            let auth = CryptoKit.HMAC<SHA512>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        }

        switch outputFormat {
        case .hex:
            return authData.map { String(format: "%02x", $0) }.joined()
        case .base64:
            return authData.base64EncodedString()
        }
    }
}
