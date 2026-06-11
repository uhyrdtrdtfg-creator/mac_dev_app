import Foundation
import CryptoKit

public enum HashAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"
    case sha3_256 = "SHA3-256"
    case sha3_512 = "SHA3-512"
    case crc32 = "CRC32"

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
        case .sha3_256:
            Keccak.sha3_256(data).map { String(format: "%02x", $0) }.joined()
        case .sha3_512:
            Keccak.sha3_512(data).map { String(format: "%02x", $0) }.joined()
        case .crc32:
            crc32(data)
        }
    }

    private static let crc32Table: [UInt32] = (0..<256).map { i in
        var c = UInt32(i)
        for _ in 0..<8 {
            c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1
        }
        return c
    }

    private static func crc32(_ data: Data) -> String {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc = crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)] ^ (crc >> 8)
        }
        return String(format: "%08x", crc ^ 0xFFFFFFFF)
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
