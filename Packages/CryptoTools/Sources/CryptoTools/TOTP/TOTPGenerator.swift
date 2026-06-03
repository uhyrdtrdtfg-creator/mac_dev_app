import Foundation
import CryptoKit

public enum TOTPAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case sha1 = "SHA1"
    case sha256 = "SHA256"
    case sha512 = "SHA512"
    public var id: String { rawValue }
}

public struct OTPAuthConfig: Sendable {
    public var secret: String
    public var algorithm: TOTPAlgorithm
    public var digits: Int
    public var period: Int
    public var issuer: String?
    public var label: String?
}

public enum TOTPGenerator {
    /// Decode an RFC 4648 Base32 string (case-insensitive, padding/spaces ignored).
    public static func base32Decode(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var lookup = [Character: UInt8]()
        for (i, c) in alphabet.enumerated() { lookup[c] = UInt8(i) }

        let cleaned = string.uppercased().filter { $0 != "=" && !$0.isWhitespace }
        guard !cleaned.isEmpty else { return nil }

        var bits = 0
        var value = 0
        var output = [UInt8]()
        for c in cleaned {
            guard let v = lookup[c] else { return nil }
            value = (value << 5) | Int(v)
            bits += 5
            if bits >= 8 {
                bits -= 8
                output.append(UInt8((value >> bits) & 0xFF))
            }
        }
        return Data(output)
    }

    /// HOTP (RFC 4226) for a given counter.
    public static func hotp(secret: Data, counter: UInt64, algorithm: TOTPAlgorithm, digits: Int) -> String {
        var bigEndianCounter = counter.bigEndian
        let counterData = withUnsafeBytes(of: &bigEndianCounter) { Data($0) }
        let key = SymmetricKey(data: secret)

        let hmac: Data
        switch algorithm {
        case .sha1: hmac = Data(CryptoKit.HMAC<Insecure.SHA1>.authenticationCode(for: counterData, using: key))
        case .sha256: hmac = Data(CryptoKit.HMAC<SHA256>.authenticationCode(for: counterData, using: key))
        case .sha512: hmac = Data(CryptoKit.HMAC<SHA512>.authenticationCode(for: counterData, using: key))
        }

        let bytes = [UInt8](hmac)
        let offset = Int(bytes[bytes.count - 1] & 0x0F)
        let binary = (UInt32(bytes[offset] & 0x7F) << 24)
            | (UInt32(bytes[offset + 1]) << 16)
            | (UInt32(bytes[offset + 2]) << 8)
            | UInt32(bytes[offset + 3])
        let mod = UInt32(pow(10, Double(digits)))
        let code = binary % mod
        return String(format: "%0\(digits)u", code)
    }

    /// TOTP (RFC 6238). Returns nil if the secret is not valid Base32.
    public static func generate(secretBase32: String, algorithm: TOTPAlgorithm = .sha1, digits: Int = 6, period: Int = 30, date: Date = Date()) -> String? {
        guard period > 0, let secret = base32Decode(secretBase32), !secret.isEmpty else { return nil }
        let counter = UInt64(date.timeIntervalSince1970 / Double(period))
        return hotp(secret: secret, counter: counter, algorithm: algorithm, digits: digits)
    }

    /// Seconds remaining in the current time step.
    public static func remainingSeconds(period: Int = 30, date: Date = Date()) -> Int {
        guard period > 0 else { return 0 }
        return period - Int(date.timeIntervalSince1970.truncatingRemainder(dividingBy: Double(period)))
    }

    /// Parse an `otpauth://totp/...` URI into its components.
    public static func parseOTPAuth(_ uri: String) -> OTPAuthConfig? {
        guard let components = URLComponents(string: uri.trimmingCharacters(in: .whitespaces)),
              components.scheme?.lowercased() == "otpauth" else { return nil }
        let query = components.queryItems ?? []
        func value(_ name: String) -> String? { query.first { $0.name.lowercased() == name }?.value }
        guard let secret = value("secret") else { return nil }

        let algorithm = TOTPAlgorithm(rawValue: (value("algorithm") ?? "SHA1").uppercased()) ?? .sha1
        let digits = Int(value("digits") ?? "6") ?? 6
        let period = Int(value("period") ?? "30") ?? 30
        let label = components.path.hasPrefix("/") ? String(components.path.dropFirst()) : components.path
        return OTPAuthConfig(secret: secret, algorithm: algorithm, digits: digits, period: period,
                             issuer: value("issuer"), label: label.isEmpty ? nil : label)
    }
}
