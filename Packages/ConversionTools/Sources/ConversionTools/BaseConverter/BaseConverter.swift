import Foundation

public enum NumberBase: String, CaseIterable, Identifiable, Sendable {
    case binary = "Binary (2)"; case octal = "Octal (8)"; case decimal = "Decimal (10)"; case hex = "Hex (16)"
    public var id: String { rawValue }
    public var radix: Int { switch self { case .binary: 2; case .octal: 8; case .decimal: 10; case .hex: 16 } }
}

public enum BaseConverter {
    public static func convert(_ input: String, from: NumberBase, to: NumberBase) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: "0b", with: "").replacingOccurrences(of: "0o", with: "")
        guard !trimmed.isEmpty, let value = UInt64(trimmed, radix: from.radix) else { return nil }
        return String(value, radix: to.radix, uppercase: to == .hex)
    }
    public static func convertAll(_ input: String, from: NumberBase) -> [NumberBase: String] {
        var r: [NumberBase: String] = [:]; for b in NumberBase.allCases { r[b] = convert(input, from: from, to: b) }; return r
    }
}
