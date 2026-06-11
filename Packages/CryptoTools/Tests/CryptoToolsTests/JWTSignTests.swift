import Testing
import Foundation
import Security
@testable import CryptoTools

@Test func hmacSignVerifyRoundtrip() throws {
    for alg in [JWTAlgorithm.hs256, .hs384, .hs512] {
        let (token, error) = JWTTool.sign(payloadJSON: #"{"sub":"abc","iat":1700000000}"#, algorithm: alg, key: "topsecret")
        #expect(error == nil)
        let signed = try #require(token)
        #expect(JWTTool.verify(signed, key: "topsecret") == .valid)
        #expect(JWTTool.verify(signed, key: "wrong") == .invalid)
        let decoded = try JWTTool.decode(signed)
        #expect(decoded.algorithm == alg.rawValue)
        #expect(decoded.type == "JWT")
    }
}

@Test func hs256KnownVector() {
    // Classic jwt.io example: exact key order is preserved by sign().
    let payload = #"{"sub":"1234567890","name":"John Doe","iat":1516239022}"#
    let (token, error) = JWTTool.sign(payloadJSON: payload, algorithm: .hs256, key: "your-256-bit-secret")
    #expect(error == nil)
    #expect(token == "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c")
}

@Test func rsaSignVerifyRoundtripPKCS1() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    for alg in [JWTAlgorithm.rs256, .rs384, .rs512] {
        let (token, error) = JWTTool.sign(payloadJSON: #"{"sub":"rsa-test"}"#, algorithm: alg, key: keyPair.privateKeyPEM)
        #expect(error == nil)
        let signed = try #require(token)
        #expect(JWTTool.verify(signed, key: keyPair.publicKeyPEM) == .valid)
    }
}

@Test func rs256SignVerifyRoundtripPKCS8() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let base64 = keyPair.privateKeyPEM
        .replacingOccurrences(of: "-----BEGIN RSA PRIVATE KEY-----", with: "")
        .replacingOccurrences(of: "-----END RSA PRIVATE KEY-----", with: "")
        .components(separatedBy: .whitespacesAndNewlines).joined()
    let pkcs1DER = try #require(Data(base64Encoded: base64))
    let pkcs8 = pkcs8PEM(fromPKCS1: pkcs1DER)
    let (token, error) = JWTTool.sign(payloadJSON: #"{"sub":"pkcs8-test"}"#, algorithm: .rs256, key: pkcs8)
    #expect(error == nil)
    let signed = try #require(token)
    #expect(JWTTool.verify(signed, key: keyPair.publicKeyPEM) == .valid)
}

@Test func publicKeyDerivedFromPrivateVerifies() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let (token, _) = JWTTool.sign(payloadJSON: #"{"sub":"derive"}"#, algorithm: .rs256, key: keyPair.privateKeyPEM)
    let signed = try #require(token)
    let derivedPublic = try #require(JWTTool.publicKeyPEM(fromPrivatePEM: keyPair.privateKeyPEM))
    #expect(JWTTool.verify(signed, key: derivedPublic) == .valid)
}

@Test func tamperedPayloadFailsVerify() throws {
    let (token, _) = JWTTool.sign(payloadJSON: #"{"sub":"original"}"#, algorithm: .hs256, key: "s3cret")
    var segments = try #require(token).split(separator: ".").map(String.init)
    segments[1] = JWTTool.base64URLEncode(Data(#"{"sub":"tampered"}"#.utf8))
    #expect(JWTTool.verify(segments.joined(separator: "."), key: "s3cret") == .invalid)
}

@Test func expiredExpFlaggedByDecode() throws {
    let (token, _) = JWTTool.sign(payloadJSON: #"{"sub":"x","exp":1000000000}"#, algorithm: .hs256, key: "s")
    let decoded = try JWTTool.decode(try #require(token))
    #expect(decoded.claims.contains { $0.key.contains("exp") && $0.note == "⚠️ EXPIRED" })
}

@Test func invalidPayloadJSONErrors() {
    for bad in ["not json", "", "[1,2,3]", #""string""#] {
        let (token, error) = JWTTool.sign(payloadJSON: bad, algorithm: .hs256, key: "s")
        #expect(token == nil)
        #expect(error == "Payload must be a valid JSON object")
    }
}

@Test func emptyKeyErrors() {
    let (hsToken, hsError) = JWTTool.sign(payloadJSON: #"{"a":1}"#, algorithm: .hs256, key: "")
    #expect(hsToken == nil)
    #expect(hsError == "HMAC secret cannot be empty")
    let (rsToken, rsError) = JWTTool.sign(payloadJSON: #"{"a":1}"#, algorithm: .rs256, key: "")
    #expect(rsToken == nil)
    #expect(rsError == "Private key cannot be empty")
}

@Test func wrongKeyTypeErrors() throws {
    // EC key supplied where an RSA private key is expected.
    let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeySizeInBits as String: 256]
    var cfError: Unmanaged<CFError>?
    let ecKey = try #require(SecKeyCreateRandomKey(attrs as CFDictionary, &cfError))
    let ecData = try #require(SecKeyCopyExternalRepresentation(ecKey, &cfError)) as Data
    let ecPEM = "-----BEGIN PRIVATE KEY-----\n\(ecData.base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed]))\n-----END PRIVATE KEY-----"
    let (token, error) = JWTTool.sign(payloadJSON: #"{"a":1}"#, algorithm: .rs256, key: ecPEM)
    #expect(token == nil)
    #expect(error?.contains("Invalid RSA private key") == true)
}

@Test func extraHeaderMergedAlgProtected() throws {
    let (token, error) = JWTTool.sign(payloadJSON: #"{"a":1}"#, algorithm: .hs256, key: "s",
                                      extraHeader: #"{"kid":"key-1","alg":"none"}"#)
    #expect(error == nil)
    let decoded = try JWTTool.decode(try #require(token))
    #expect(decoded.algorithm == "HS256")
    #expect(decoded.headerJSON.contains(#""kid""#))
    #expect(JWTTool.verify(try #require(token), key: "s") == .valid)
}

@Test func invalidExtraHeaderErrors() {
    let (token, error) = JWTTool.sign(payloadJSON: #"{"a":1}"#, algorithm: .hs256, key: "s", extraHeader: "nope")
    #expect(token == nil)
    #expect(error == "Custom header must be a valid JSON object")
}

// MARK: - Helpers

/// Wrap a PKCS#1 RSAPrivateKey DER blob in a PKCS#8 PrivateKeyInfo envelope.
private func pkcs8PEM(fromPKCS1 der: Data) -> String {
    func derLength(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var bytes: [UInt8] = []
        var v = n
        while v > 0 { bytes.insert(UInt8(v & 0xff), at: 0); v >>= 8 }
        return [0x80 | UInt8(bytes.count)] + bytes
    }
    let version: [UInt8] = [0x02, 0x01, 0x00]
    let rsaAlgID: [UInt8] = [0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00]
    let octetString: [UInt8] = [0x04] + derLength(der.count) + [UInt8](der)
    let body = version + rsaAlgID + octetString
    let full: [UInt8] = [0x30] + derLength(body.count) + body
    let base64 = Data(full).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
    return "-----BEGIN PRIVATE KEY-----\n\(base64)\n-----END PRIVATE KEY-----"
}
