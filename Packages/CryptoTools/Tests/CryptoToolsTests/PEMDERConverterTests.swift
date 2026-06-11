import Testing
import Foundation
@testable import CryptoTools

@Test func pemDerRoundTripPreservesPayloadAndLabel() throws {
    let payload = Data((0..<200).map { UInt8($0 % 251) })
    let pem = PEMDERConverter.derToPEM(payload, label: .publicKey)
    let result = try PEMDERConverter.decodePEM(pem)
    #expect(result.der == payload)
    #expect(result.label == "PUBLIC KEY")
    #expect(result.blockCount == 1)
    #expect(try PEMDERConverter.pemToDER(pem) == payload)
}

@Test func pemDerRoundTripAllLabels() throws {
    let payload = Data("arbitrary payload bytes".utf8)
    for label in PEMLabel.allCases {
        let pem = PEMDERConverter.derToPEM(payload, label: label)
        #expect(pem.hasPrefix("-----BEGIN \(label.rawValue)-----\n"))
        #expect(pem.contains("-----END \(label.rawValue)-----"))
        let result = try PEMDERConverter.decodePEM(pem)
        #expect(result.der == payload)
        #expect(result.label == label.rawValue)
    }
}

@Test func derToPEMWrapsBase64At64Characters() {
    // 150 bytes -> 200 base64 chars -> lines of 64, 64, 64, 8.
    let payload = Data(repeating: 0xAB, count: 150)
    let pem = PEMDERConverter.derToPEM(payload, label: .certificate)
    let lines = pem.split(separator: "\n").map(String.init)
    #expect(lines.first == "-----BEGIN CERTIFICATE-----")
    #expect(lines.last == "-----END CERTIFICATE-----")
    let bodyLines = lines.dropFirst().dropLast()
    #expect(!bodyLines.isEmpty)
    for line in bodyLines.dropLast() {
        #expect(line.count == 64)
    }
    if let last = bodyLines.last {
        #expect(last.count <= 64 && !last.isEmpty)
    }
    #expect(bodyLines.joined() == payload.base64EncodedString())
}

@Test func multiBlockPEMPicksFirstAndReportsCount() throws {
    let first = Data("first block".utf8)
    let second = Data("second block".utf8)
    let pem = PEMDERConverter.derToPEM(first, label: .certificate)
        + "\n"
        + PEMDERConverter.derToPEM(second, label: .rsaPrivateKey)
    let result = try PEMDERConverter.decodePEM(pem)
    #expect(result.der == first)
    #expect(result.label == "CERTIFICATE")
    #expect(result.blockCount == 2)
}

@Test func invalidArmorThrows() {
    #expect(throws: PEMDERError.invalidPEMArmor) {
        try PEMDERConverter.pemToDER("just some text without any armor")
    }
    // Mismatched BEGIN/END labels are not a valid block.
    #expect(throws: PEMDERError.invalidPEMArmor) {
        try PEMDERConverter.pemToDER("-----BEGIN CERTIFICATE-----\nAAAA\n-----END PUBLIC KEY-----")
    }
    // BEGIN without END.
    #expect(throws: PEMDERError.invalidPEMArmor) {
        try PEMDERConverter.pemToDER("-----BEGIN CERTIFICATE-----\nAAAA\n")
    }
}

@Test func invalidBase64Throws() {
    #expect(throws: PEMDERError.invalidBase64) {
        try PEMDERConverter.pemToDER("-----BEGIN CERTIFICATE-----\n!!!not base64!!!\n-----END CERTIFICATE-----")
    }
    // Empty body is also invalid.
    #expect(throws: PEMDERError.invalidBase64) {
        try PEMDERConverter.pemToDER("-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----")
    }
}

@Test func emptyInputThrows() {
    #expect(throws: PEMDERError.emptyInput) {
        try PEMDERConverter.pemToDER("")
    }
    #expect(throws: PEMDERError.emptyInput) {
        try PEMDERConverter.pemToDER("   \n\t ")
    }
}

@Test func labelDetectionReturnsNilForNonCertificateData() {
    // Arbitrary bytes are not an X.509 certificate, so detection should defer to the user.
    let payload = Data("definitely not a certificate".utf8)
    #expect(PEMDERConverter.detectLabel(for: payload) == nil)
}

@Test func pemLabelDisplayNames() {
    #expect(PEMLabel.certificate.displayName == "Certificate")
    #expect(PEMLabel.publicKey.displayName == "Public Key")
    #expect(PEMLabel.privateKey.displayName == "Private Key (PKCS#8)")
    #expect(PEMLabel.rsaPrivateKey.displayName == "RSA Private Key")
    #expect(PEMLabel.ecPrivateKey.displayName == "EC Private Key")
    #expect(PEMLabel.certificateRequest.displayName == "Certificate Request")
}
