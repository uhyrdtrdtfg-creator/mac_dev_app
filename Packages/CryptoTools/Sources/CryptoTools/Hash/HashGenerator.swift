import Foundation
import CryptoKit

public enum HashAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    public var id: String { rawValue }
}

public enum HashGenerator {
    public static func hash(_ string: String, algorithm: HashAlgorithm) -> String {
        hash(data: Data(string.utf8), algorithm: algorithm)
    }

    public static func hash(data: Data, algorithm: HashAlgorithm) -> String {
        switch algorithm {
        case .md5:
            Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha1:
            Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha512:
            SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    public static func hashAll(_ string: String) -> [HashAlgorithm: String] {
        hashAll(data: Data(string.utf8))
    }

    public static func hashAll(data: Data) -> [HashAlgorithm: String] {
        var results: [HashAlgorithm: String] = [:]
        for algorithm in HashAlgorithm.allCases {
            results[algorithm] = hash(data: data, algorithm: algorithm)
        }
        return results
    }
}
