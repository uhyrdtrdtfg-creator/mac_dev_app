import Foundation
import CryptoKit
import Security

public struct JWTClaim: Identifiable, Sendable {
    public let id = UUID()
    public let key: String
    public let value: String
    public let note: String?

    public init(key: String, value: String, note: String? = nil) {
        self.key = key
        self.value = value
        self.note = note
    }
}

public struct JWTDecoded: Sendable {
    public let headerJSON: String
    public let payloadJSON: String
    public let signatureBase64URL: String
    public let algorithm: String
    public let type: String?
    public let signingInput: String
    public let claims: [JWTClaim]
}

public enum JWTVerification: Sendable, Equatable {
    case valid
    case invalid
    case unsupported(String)
    case missingKey
    case error(String)
}

public enum JWTAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case hs256 = "HS256", hs384 = "HS384", hs512 = "HS512"
    case rs256 = "RS256", rs384 = "RS384", rs512 = "RS512"
    public var id: String { rawValue }
    public var isHMAC: Bool { rawValue.hasPrefix("HS") }

    var rsaSignatureAlgorithm: SecKeyAlgorithm {
        switch self {
        case .rs384: .rsaSignatureMessagePKCS1v15SHA384
        case .rs512: .rsaSignatureMessagePKCS1v15SHA512
        default: .rsaSignatureMessagePKCS1v15SHA256
        }
    }
}

public enum JWTError: Error, LocalizedError {
    case malformed
    case invalidBase64
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .malformed: "JWT must have 3 dot-separated parts (header.payload.signature)"
        case .invalidBase64: "A JWT segment is not valid Base64URL"
        case .invalidJSON: "A JWT segment is not valid JSON"
        }
    }
}

public enum JWTTool {
    /// Decode a JWT into pretty-printed header/payload plus interpreted standard claims.
    public static func decode(_ token: String, now: Date = Date()) throws -> JWTDecoded {
        let segments = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { throw JWTError.malformed }

        let headerData = try base64URLDecode(String(segments[0]))
        let payloadData = try base64URLDecode(String(segments[1]))

        let headerObj = try jsonObject(headerData)
        let payloadObj = try jsonObject(payloadData)

        let alg = (headerObj["alg"] as? String) ?? "none"
        let typ = headerObj["typ"] as? String

        return JWTDecoded(
            headerJSON: try prettyJSON(headerData),
            payloadJSON: try prettyJSON(payloadData),
            signatureBase64URL: String(segments[2]),
            algorithm: alg,
            type: typ,
            signingInput: "\(segments[0]).\(segments[1])",
            claims: interpretClaims(payloadObj, now: now)
        )
    }

    /// Verify a JWT signature. `key` is the HMAC secret for HS* or a PEM public key for RS*.
    public static func verify(_ token: String, key: String) -> JWTVerification {
        let segments = token.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { return .error("Malformed token") }

        guard let headerData = try? base64URLDecode(String(segments[0])),
              let header = try? jsonObject(headerData),
              let alg = header["alg"] as? String else {
            return .error("Cannot read alg from header")
        }

        let signingInput = Data("\(segments[0]).\(segments[1])".utf8)
        guard let signature = try? base64URLDecode(String(segments[2])) else {
            return .error("Invalid signature encoding")
        }
        guard !key.isEmpty else { return .missingKey }

        switch alg.uppercased() {
        case "HS256": return verifyHMAC(signingInput, signature, secret: key, hash: SHA256.self)
        case "HS384": return verifyHMAC(signingInput, signature, secret: key, hash: SHA384.self)
        case "HS512": return verifyHMAC(signingInput, signature, secret: key, hash: SHA512.self)
        case "RS256": return verifyRSA(signingInput, signature, pem: key, algorithm: .rsaSignatureMessagePKCS1v15SHA256)
        case "RS384": return verifyRSA(signingInput, signature, pem: key, algorithm: .rsaSignatureMessagePKCS1v15SHA384)
        case "RS512": return verifyRSA(signingInput, signature, pem: key, algorithm: .rsaSignatureMessagePKCS1v15SHA512)
        default: return .unsupported(alg)
        }
    }

    /// Sign a JWT. `key` is the HMAC secret for HS* or a PEM RSA private key (PKCS#1 or PKCS#8) for RS*.
    /// The payload JSON string is encoded as-is (preserving key order); the header is auto-built and
    /// merged with optional extra header JSON (user keys win, except `alg`).
    public static func sign(payloadJSON: String, algorithm: JWTAlgorithm, key: String, extraHeader: String? = nil) -> (token: String?, error: String?) {
        let payload = payloadJSON.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !payload.isEmpty,
              let payloadObj = try? JSONSerialization.jsonObject(with: Data(payload.utf8)),
              payloadObj is [String: Any] else {
            return (nil, "Payload must be a valid JSON object")
        }
        guard !key.isEmpty else {
            return (nil, algorithm.isHMAC ? "HMAC secret cannot be empty" : "Private key cannot be empty")
        }

        var headerJSON = #"{"alg":"\#(algorithm.rawValue)","typ":"JWT"}"#
        if let extra = extraHeader?.trimmingCharacters(in: .whitespacesAndNewlines), !extra.isEmpty {
            guard let extraObj = try? JSONSerialization.jsonObject(with: Data(extra.utf8)) as? [String: Any] else {
                return (nil, "Custom header must be a valid JSON object")
            }
            var header: [String: Any] = ["alg": algorithm.rawValue, "typ": "JWT"]
            for (k, v) in extraObj where k != "alg" { header[k] = v }
            guard let headerData = try? JSONSerialization.data(withJSONObject: header, options: [.sortedKeys, .withoutEscapingSlashes]) else {
                return (nil, "Cannot serialize header JSON")
            }
            headerJSON = String(decoding: headerData, as: UTF8.self)
        }

        let signingInput = "\(base64URLEncode(Data(headerJSON.utf8))).\(base64URLEncode(Data(payload.utf8)))"
        let inputData = Data(signingInput.utf8)

        let signature: Data
        switch algorithm {
        case .hs256: signature = signHMAC(inputData, secret: key, hash: SHA256.self)
        case .hs384: signature = signHMAC(inputData, secret: key, hash: SHA384.self)
        case .hs512: signature = signHMAC(inputData, secret: key, hash: SHA512.self)
        case .rs256, .rs384, .rs512:
            guard let secKey = privateSecKey(fromPEM: key) else {
                return (nil, "Invalid RSA private key PEM (expecting -----BEGIN RSA PRIVATE KEY----- or -----BEGIN PRIVATE KEY-----)")
            }
            var error: Unmanaged<CFError>?
            guard let sig = SecKeyCreateSignature(secKey, algorithm.rsaSignatureAlgorithm, inputData as CFData, &error) else {
                let reason = (error?.takeRetainedValue()).map { CFErrorCopyDescription($0) as String } ?? "unknown error"
                return (nil, "Signing failed: \(reason)")
            }
            signature = sig as Data
        }
        return ("\(signingInput).\(base64URLEncode(signature))", nil)
    }

    /// Derive the public key PEM from an RSA private key PEM (e.g. to self-verify a freshly signed token).
    public static func publicKeyPEM(fromPrivatePEM pem: String) -> String? {
        guard let privateKey = privateSecKey(fromPEM: pem),
              let publicKey = SecKeyCopyPublicKey(privateKey),
              let data = SecKeyCopyExternalRepresentation(publicKey, nil) else { return nil }
        let base64 = (data as Data).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        return "-----BEGIN PUBLIC KEY-----\n\(base64)\n-----END PUBLIC KEY-----"
    }

    // MARK: - HMAC

    private static func signHMAC<H: HashFunction>(_ input: Data, secret: String, hash: H.Type) -> Data {
        Data(CryptoKit.HMAC<H>.authenticationCode(for: input, using: SymmetricKey(data: Data(secret.utf8))))
    }

    private static func verifyHMAC<H: HashFunction>(_ input: Data, _ signature: Data, secret: String, hash: H.Type) -> JWTVerification {
        let symKey = SymmetricKey(data: Data(secret.utf8))
        let computed = Data(CryptoKit.HMAC<H>.authenticationCode(for: input, using: symKey))
        return constantTimeEqual(computed, signature) ? .valid : .invalid
    }

    // MARK: - RSA

    private static func verifyRSA(_ input: Data, _ signature: Data, pem: String, algorithm: SecKeyAlgorithm) -> JWTVerification {
        guard let key = publicSecKey(fromPEM: pem) else {
            return .error("Invalid RSA public key PEM (expecting -----BEGIN PUBLIC KEY-----)")
        }
        var error: Unmanaged<CFError>?
        let ok = SecKeyVerifySignature(key, algorithm, input as CFData, signature as CFData, &error)
        return ok ? .valid : .invalid
    }

    private static func publicSecKey(fromPEM pem: String) -> SecKey? {
        let cleaned = pem
            .replacingOccurrences(of: "-----BEGIN PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN RSA PUBLIC KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PUBLIC KEY-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines).joined()
        guard let der = Data(base64Encoded: cleaned) else { return nil }
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic
        ]
        var error: Unmanaged<CFError>?
        // SecKeyCreateWithData expects a PKCS#1 RSAPublicKey; strip SPKI wrapper if present.
        let keyData = stripSPKIHeader(der) ?? der
        return SecKeyCreateWithData(keyData as CFData, attrs as CFDictionary, &error)
    }

    private static func privateSecKey(fromPEM pem: String) -> SecKey? {
        let cleaned = pem
            .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----BEGIN PRIVATE KEY-----", with: "")
            .replacingOccurrences(of: "-----END PRIVATE KEY-----", with: "")
            .components(separatedBy: .whitespacesAndNewlines).joined()
        guard let der = Data(base64Encoded: cleaned) else { return nil }
        let attrs: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate
        ]
        var error: Unmanaged<CFError>?
        // SecKeyCreateWithData expects a PKCS#1 RSAPrivateKey; strip the PKCS#8 wrapper if present.
        let keyData = stripPKCS8Header(der) ?? der
        return SecKeyCreateWithData(keyData as CFData, attrs as CFDictionary, &error)
    }

    /// Best-effort extraction of the PKCS#1 RSAPrivateKey from a PKCS#8 PrivateKeyInfo DER blob.
    private static func stripPKCS8Header(_ der: Data) -> Data? {
        let bytes = [UInt8](der)
        // PKCS#8: SEQUENCE { INTEGER 0, SEQUENCE { OID rsaEncryption, NULL }, OCTET STRING { RSAPrivateKey } }
        let rsaOIDHeader: [UInt8] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
        guard bytes.first == 0x30, let range = find(rsaOIDHeader, in: bytes) else { return nil }
        var idx = range + rsaOIDHeader.count
        guard idx < bytes.count, bytes[idx] == 0x04 else { return nil } // OCTET STRING
        idx += 1
        guard let (_, lenBytes) = parseDERLength(bytes, at: idx) else { return nil }
        idx += lenBytes
        guard idx < bytes.count else { return nil }
        return Data(bytes[idx...])
    }

    /// Best-effort extraction of the PKCS#1 RSAPublicKey from an SPKI (X.509 SubjectPublicKeyInfo) DER blob.
    private static func stripSPKIHeader(_ der: Data) -> Data? {
        let bytes = [UInt8](der)
        // SPKI: SEQUENCE { SEQUENCE { OID rsaEncryption, NULL }, BIT STRING { RSAPublicKey } }
        // The 1.2.840.113549.1.1.1 OID header is a known 15-byte prefix for the inner AlgorithmIdentifier.
        let rsaOIDHeader: [UInt8] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
        guard bytes.first == 0x30 else { return nil }
        // Find the OID header inside the blob.
        guard let range = find(rsaOIDHeader, in: bytes) else { return nil }
        var idx = range + rsaOIDHeader.count
        guard idx < bytes.count, bytes[idx] == 0x03 else { return nil } // BIT STRING
        idx += 1
        // Parse BIT STRING length.
        guard let (_, lenBytes) = parseDERLength(bytes, at: idx) else { return nil }
        idx += lenBytes
        guard idx < bytes.count, bytes[idx] == 0x00 else { return nil } // unused-bits octet
        idx += 1
        return Data(bytes[idx...])
    }

    private static func parseDERLength(_ bytes: [UInt8], at index: Int) -> (length: Int, bytesConsumed: Int)? {
        guard index < bytes.count else { return nil }
        let first = bytes[index]
        if first < 0x80 { return (Int(first), 1) }
        let count = Int(first & 0x7f)
        guard count > 0, index + count < bytes.count else { return nil }
        var len = 0
        for i in 1...count { len = (len << 8) | Int(bytes[index + i]) }
        return (len, count + 1)
    }

    private static func find(_ needle: [UInt8], in haystack: [UInt8]) -> Int? {
        guard !needle.isEmpty, haystack.count >= needle.count else { return nil }
        for i in 0...(haystack.count - needle.count) where Array(haystack[i..<i + needle.count]) == needle {
            return i
        }
        return nil
    }

    private static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) { diff |= x ^ y }
        return diff == 0
    }

    // MARK: - Claims

    private static func interpretClaims(_ payload: [String: Any], now: Date) -> [JWTClaim] {
        var claims: [JWTClaim] = []
        let labels: [String: String] = [
            "iss": "Issuer", "sub": "Subject", "aud": "Audience",
            "exp": "Expires", "nbf": "Not Before", "iat": "Issued At", "jti": "JWT ID"
        ]
        for key in ["iss", "sub", "aud", "exp", "nbf", "iat", "jti"] {
            guard let raw = payload[key] else { continue }
            let label = labels[key] ?? key
            if key == "exp" || key == "nbf" || key == "iat", let epoch = numericValue(raw) {
                let date = Date(timeIntervalSince1970: epoch)
                let formatted = isoString(date)
                var note: String? = nil
                if key == "exp" { note = date < now ? "⚠️ EXPIRED" : "valid" }
                if key == "nbf" { note = date > now ? "⚠️ not yet valid" : "active" }
                claims.append(JWTClaim(key: "\(label) (\(key))", value: formatted, note: note))
            } else {
                claims.append(JWTClaim(key: "\(label) (\(key))", value: stringValue(raw)))
            }
        }
        return claims
    }

    private static func numericValue(_ any: Any) -> Double? {
        if let d = any as? Double { return d }
        if let i = any as? Int { return Double(i) }
        if let n = any as? NSNumber { return n.doubleValue }
        if let s = any as? String { return Double(s) }
        return nil
    }

    private static func stringValue(_ any: Any) -> String {
        if let s = any as? String { return s }
        if let arr = any as? [Any] { return arr.map { stringValue($0) }.joined(separator: ", ") }
        return "\(any)"
    }

    // MARK: - Encoding helpers

    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    static func base64URLDecode(_ string: String) throws -> Data {
        var s = string.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = s.count % 4
        if remainder > 0 { s += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: s) else { throw JWTError.invalidBase64 }
        return data
    }

    private static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw JWTError.invalidJSON
        }
        return obj
    }

    private static func prettyJSON(_ data: Data) throws -> String {
        guard let obj = try? JSONSerialization.jsonObject(with: data) else { throw JWTError.invalidJSON }
        let pretty = try JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        return String(decoding: pretty, as: UTF8.self)
    }

    private static func isoString(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
