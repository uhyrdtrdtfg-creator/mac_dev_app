import Foundation

public enum UUIDGenerator {
    public static func generateV4() -> String { UUID().uuidString }
    public static func generateBatch(_ count: Int) -> [String] { (0..<count).map { _ in UUID().uuidString } }
    public static func decode(_ uuidString: String) -> UUIDInfo? {
        guard let _ = UUID(uuidString: uuidString) else { return nil }
        let clean = uuidString.replacingOccurrences(of: "-", with: "")
        guard clean.count == 32 else { return nil }
        let versionChar = clean[clean.index(clean.startIndex, offsetBy: 12)]
        return UUIDInfo(version: Int(String(versionChar), radix: 16) ?? 0, variant: "RFC 4122", hex: clean.lowercased())
    }
}

public struct UUIDInfo: Sendable {
    public let version: Int; public let variant: String; public let hex: String
}
