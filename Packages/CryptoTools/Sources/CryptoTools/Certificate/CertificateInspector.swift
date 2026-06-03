import Foundation
import Security
import CryptoKit

public struct CertificateField: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let value: String

    public init(label: String, value: String) {
        self.label = label
        self.value = value
    }
}

public struct CertificateInfo: Sendable {
    public let fields: [CertificateField]
    public let isExpired: Bool
    public let sha256Fingerprint: String
    public let sha1Fingerprint: String
}

public enum CertificateError: Error, LocalizedError {
    case noPEMFound
    case invalidDER

    public var errorDescription: String? {
        switch self {
        case .noPEMFound: "No certificate found. Paste a PEM block (-----BEGIN CERTIFICATE-----) or raw Base64 DER."
        case .invalidDER: "The data is not a valid X.509 certificate."
        }
    }
}

public enum CertificateInspector {
    public static func inspect(_ input: String, now: Date = Date()) throws -> CertificateInfo {
        let der = try derData(from: input)
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else {
            throw CertificateError.invalidDER
        }

        var fields: [CertificateField] = []

        if let summary = SecCertificateCopySubjectSummary(certificate) as String? {
            fields.append(CertificateField(label: "Subject", value: summary))
        }
        var cnRef: CFString?
        if SecCertificateCopyCommonName(certificate, &cnRef) == errSecSuccess, let cn = cnRef as String? {
            fields.append(CertificateField(label: "Common Name", value: cn))
        }

        var isExpired = false
        let values = SecCertificateCopyValues(certificate, nil, nil) as? [CFString: Any]

        if let notBefore = dateValue(values, key: kSecOIDX509V1ValidityNotBefore) {
            fields.append(CertificateField(label: "Valid From", value: format(notBefore)))
        }
        if let notAfter = dateValue(values, key: kSecOIDX509V1ValidityNotAfter) {
            isExpired = notAfter < now
            let status = isExpired ? "  ⚠️ EXPIRED" : ""
            fields.append(CertificateField(label: "Valid Until", value: format(notAfter) + status))
        }
        if let serialData = SecCertificateCopySerialNumberData(certificate, nil) as Data? {
            fields.append(CertificateField(label: "Serial Number", value: hexColon(serialData)))
        }
        if let issuer = nameValue(values, key: kSecOIDX509V1IssuerName) {
            fields.append(CertificateField(label: "Issuer", value: issuer))
        }
        if let subject = nameValue(values, key: kSecOIDX509V1SubjectName) {
            fields.append(CertificateField(label: "Subject (full)", value: subject))
        }
        for san in subjectAltNames(values) {
            fields.append(CertificateField(label: "Subject Alt Name", value: san))
        }
        fields.append(CertificateField(label: "Size", value: "\(der.count) bytes"))

        let sha256 = SHA256.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")
        let sha1 = Insecure.SHA1.hash(data: der).map { String(format: "%02X", $0) }.joined(separator: ":")

        return CertificateInfo(fields: fields, isExpired: isExpired, sha256Fingerprint: sha256, sha1Fingerprint: sha1)
    }

    // MARK: - Parsing helpers

    private static func derData(from input: String) throws -> Data {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CertificateError.noPEMFound }
        let base64: String
        if trimmed.contains("-----BEGIN") {
            base64 = trimmed
                .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
                .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
                .components(separatedBy: .whitespacesAndNewlines).joined()
        } else {
            base64 = trimmed.components(separatedBy: .whitespacesAndNewlines).joined()
        }
        guard let der = Data(base64Encoded: base64) else { throw CertificateError.invalidDER }
        return der
    }

    private static func dateValue(_ values: [CFString: Any]?, key: CFString) -> Date? {
        guard let dict = values?[key] as? [CFString: Any],
              let number = dict[kSecPropertyKeyValue] as? NSNumber else { return nil }
        // X.509 validity values are CFAbsoluteTime (seconds since 2001-01-01).
        return Date(timeIntervalSinceReferenceDate: number.doubleValue)
    }

    private static func nameValue(_ values: [CFString: Any]?, key: CFString) -> String? {
        guard let dict = values?[key] as? [CFString: Any],
              let entries = dict[kSecPropertyKeyValue] as? [[CFString: Any]] else { return nil }
        let parts: [String] = entries.compactMap { entry in
            guard let value = entry[kSecPropertyKeyValue] as? String else { return nil }
            let label = (entry[kSecPropertyKeyLabel] as? String).map { shortLabel($0) } ?? ""
            return label.isEmpty ? value : "\(label)=\(value)"
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    private static func subjectAltNames(_ values: [CFString: Any]?) -> [String] {
        guard let dict = values?[kSecOIDSubjectAltName] as? [CFString: Any],
              let entries = dict[kSecPropertyKeyValue] as? [[CFString: Any]] else { return [] }
        return entries.compactMap { entry in
            if let value = entry[kSecPropertyKeyValue] as? String {
                let label = entry[kSecPropertyKeyLabel] as? String ?? ""
                return label.isEmpty ? value : "\(label): \(value)"
            }
            return nil
        }
    }

    private static func shortLabel(_ oid: String) -> String {
        switch oid {
        case "2.5.4.3": "CN"
        case "2.5.4.6": "C"
        case "2.5.4.7": "L"
        case "2.5.4.8": "ST"
        case "2.5.4.10": "O"
        case "2.5.4.11": "OU"
        default: oid
        }
    }

    private static func hexColon(_ data: Data) -> String {
        data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }

    private static func format(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss 'UTC'"
        f.timeZone = TimeZone(identifier: "UTC")
        return f.string(from: date)
    }
}
