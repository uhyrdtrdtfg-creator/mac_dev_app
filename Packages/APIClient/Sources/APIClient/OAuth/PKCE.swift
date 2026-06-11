import Foundation
import CryptoKit
import Security

/// RFC 7636 Proof Key for Code Exchange helpers.
public enum PKCE {
    static let allowedCharacters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    /// Generates a code verifier of 43-128 characters from the RFC 7636 unreserved set.
    public static func generateCodeVerifier(length: Int = 64) -> String {
        randomString(count: min(max(length, 43), 128))
    }

    /// S256 code challenge: base64url (no padding) of the SHA-256 digest of the verifier.
    public static func codeChallenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLNoPadding(Data(digest))
    }

    /// Random opaque state parameter for CSRF protection.
    public static func generateState() -> String {
        randomString(count: 32)
    }

    static func base64URLNoPadding(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func randomString(count: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        if status != errSecSuccess {
            for i in bytes.indices { bytes[i] = UInt8.random(in: .min ... .max) }
        }
        return String(bytes.map { allowedCharacters[Int($0) % allowedCharacters.count] })
    }
}
