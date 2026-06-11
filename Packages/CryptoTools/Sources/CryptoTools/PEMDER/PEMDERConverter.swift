import Foundation
import Security

public enum PEMLabel: String, CaseIterable, Identifiable, Sendable {
    case certificate = "CERTIFICATE"
    case publicKey = "PUBLIC KEY"
    case privateKey = "PRIVATE KEY"
    case rsaPrivateKey = "RSA PRIVATE KEY"
    case ecPrivateKey = "EC PRIVATE KEY"
    case certificateRequest = "CERTIFICATE REQUEST"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .certificate: "Certificate"
        case .publicKey: "Public Key"
        case .privateKey: "Private Key (PKCS#8)"
        case .rsaPrivateKey: "RSA Private Key"
        case .ecPrivateKey: "EC Private Key"
        case .certificateRequest: "Certificate Request"
        }
    }
}

public enum PEMDERError: Error, LocalizedError, Equatable {
    case emptyInput
    case invalidPEMArmor
    case invalidBase64

    public var errorDescription: String? {
        switch self {
        case .emptyInput: "Input is empty. Paste a PEM block (-----BEGIN ...-----)."
        case .invalidPEMArmor: "No valid PEM armor found. Expected matching -----BEGIN X----- / -----END X----- lines."
        case .invalidBase64: "The PEM body is not valid Base64."
        }
    }
}

public struct PEMDecodeResult: Sendable {
    /// DER bytes of the first PEM block.
    public let der: Data
    /// The raw armor label of the first block (e.g. "CERTIFICATE", "RSA PRIVATE KEY").
    public let label: String
    /// Total number of PEM blocks found in the input.
    public let blockCount: Int
}

public enum PEMDERConverter {
    // MARK: - PEM → DER

    /// Decodes the first PEM block in `pem`, exposing the detected label and total block count.
    public static func decodePEM(_ pem: String) throws -> PEMDecodeResult {
        let trimmed = pem.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw PEMDERError.emptyInput }

        let pattern = "-----BEGIN ([A-Z0-9 ]+)-----([\\s\\S]*?)-----END \\1-----"
        let regex = try! NSRegularExpression(pattern: pattern)
        let matches = regex.matches(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed))
        guard let first = matches.first,
              let labelRange = Range(first.range(at: 1), in: trimmed),
              let bodyRange = Range(first.range(at: 2), in: trimmed) else {
            throw PEMDERError.invalidPEMArmor
        }

        let label = String(trimmed[labelRange])
        let base64 = trimmed[bodyRange].components(separatedBy: .whitespacesAndNewlines).joined()
        guard !base64.isEmpty, let der = Data(base64Encoded: base64) else {
            throw PEMDERError.invalidBase64
        }
        return PEMDecodeResult(der: der, label: label, blockCount: matches.count)
    }

    /// Strips PEM armor from the first block and returns the Base64-decoded DER bytes.
    public static func pemToDER(_ pem: String) throws -> Data {
        try decodePEM(pem).der
    }

    // MARK: - DER → PEM

    /// Encodes DER bytes as a PEM block with 64-character base64 lines and the chosen armor label.
    public static func derToPEM(_ der: Data, label: PEMLabel) -> String {
        let base64 = der.base64EncodedString()
        var lines: [String] = []
        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: 64, limitedBy: base64.endIndex) ?? base64.endIndex
            lines.append(String(base64[index..<end]))
            index = end
        }
        let body = lines.joined(separator: "\n")
        return "-----BEGIN \(label.rawValue)-----\n\(body)\n-----END \(label.rawValue)-----\n"
    }

    /// Tries to detect the appropriate PEM label for DER bytes.
    /// Returns `.certificate` if the data parses as an X.509 certificate; `nil` otherwise.
    public static func detectLabel(for der: Data) -> PEMLabel? {
        if SecCertificateCreateWithData(nil, der as CFData) != nil {
            return .certificate
        }
        return nil
    }
}
