import Foundation

public enum SubnetError: Error, LocalizedError, Equatable {
    case invalidAddress(String)
    case invalidPrefix(String)
    case invalidMask(String)
    case invalidInput(String)
    case mixedFamilies

    public var errorDescription: String? {
        switch self {
        case .invalidAddress(let s): "Invalid address: \(s)"
        case .invalidPrefix(let s): "Invalid prefix: \(s)"
        case .invalidMask(let s): "Invalid netmask: \(s)"
        case .invalidInput(let s): "Invalid input: \(s)"
        case .mixedFamilies: "Cannot mix IPv4 and IPv6"
        }
    }
}

public enum IPv4Kind: String, Sendable {
    case privateUse = "Private (RFC 1918)"
    case loopback = "Loopback"
    case linkLocal = "Link-local"
    case cgn = "Shared / CGN (RFC 6598)"
    case multicast = "Multicast"
    case reserved = "Reserved"
    case publicUse = "Public"
}

public enum IPv6Kind: String, Sendable {
    case unspecified = "Unspecified"
    case loopback = "Loopback"
    case ipv4Mapped = "IPv4-mapped"
    case linkLocal = "Link-local"
    case uniqueLocal = "Unique local (ULA)"
    case multicast = "Multicast"
    case globalUnicast = "Global unicast"
    case reserved = "Reserved"
}

public struct IPv4Info: Equatable, Sendable {
    public let address: UInt32
    public let prefix: Int

    public init(address: UInt32, prefix: Int) {
        self.address = address
        self.prefix = prefix
    }

    public var netmask: UInt32 { SubnetCalculatorEngine.mask(fromPrefix: prefix) }
    public var wildcard: UInt32 { ~netmask }
    public var network: UInt32 { address & netmask }
    public var broadcast: UInt32 { network | wildcard }

    public var usableHostCount: UInt64 {
        switch prefix {
        case 32: 1
        case 31: 2
        default: (UInt64(1) << (32 - prefix)) - 2
        }
    }

    public var firstUsable: UInt32 { prefix >= 31 ? network : network + 1 }
    public var lastUsable: UInt32 { prefix >= 31 ? broadcast : broadcast - 1 }

    public var ipClass: String {
        switch address >> 24 {
        case 0...127: "A"
        case 128...191: "B"
        case 192...223: "C"
        case 224...239: "D"
        default: "E"
        }
    }

    public var kind: IPv4Kind {
        if within(0x7F00_0000, 8) { return .loopback }
        if within(0x0A00_0000, 8) || within(0xAC10_0000, 12) || within(0xC0A8_0000, 16) { return .privateUse }
        if within(0xA9FE_0000, 16) { return .linkLocal }
        if within(0x6440_0000, 10) { return .cgn }
        if within(0xE000_0000, 4) { return .multicast }
        if within(0xF000_0000, 4) { return .reserved }
        return .publicUse
    }

    private func within(_ net: UInt32, _ prefix: Int) -> Bool {
        (address & SubnetCalculatorEngine.mask(fromPrefix: prefix)) == net
    }
}

public struct IPv6Info: Equatable, Sendable {
    public let groups: [UInt16]
    public let prefix: Int

    public init(groups: [UInt16], prefix: Int) {
        self.groups = groups
        self.prefix = prefix
    }

    public var canonical: String { SubnetCalculatorEngine.canonical(groups) }
    public var expanded: String { SubnetCalculatorEngine.expanded(groups) }

    public var networkGroups: [UInt16] {
        let v = SubnetCalculatorEngine.value128(groups)
        let m = SubnetCalculatorEngine.mask128(prefix: prefix)
        return SubnetCalculatorEngine.groups128(high: v.high & m.high, low: v.low & m.low)
    }

    public var lastGroups: [UInt16] {
        let v = SubnetCalculatorEngine.value128(groups)
        let m = SubnetCalculatorEngine.mask128(prefix: prefix)
        return SubnetCalculatorEngine.groups128(high: (v.high & m.high) | ~m.high, low: (v.low & m.low) | ~m.low)
    }

    public var totalAddresses: String { SubnetCalculatorEngine.powerOfTwoDecimal(128 - prefix) }

    public var kind: IPv6Kind {
        if groups == [0, 0, 0, 0, 0, 0, 0, 0] { return .unspecified }
        if groups == [0, 0, 0, 0, 0, 0, 0, 1] { return .loopback }
        if Array(groups[0..<5]) == [0, 0, 0, 0, 0], groups[5] == 0xFFFF { return .ipv4Mapped }
        if groups[0] & 0xFFC0 == 0xFE80 { return .linkLocal }
        if groups[0] & 0xFE00 == 0xFC00 { return .uniqueLocal }
        if groups[0] & 0xFF00 == 0xFF00 { return .multicast }
        if groups[0] & 0xE000 == 0x2000 { return .globalUnicast }
        return .reserved
    }
}

public enum ParsedSubnet: Equatable, Sendable {
    case v4(IPv4Info)
    case v6(IPv6Info)
}

public enum SubnetCalculatorEngine {
    // MARK: - IPv4

    public static func ipv4Value(_ s: String) -> UInt32? {
        let parts = s.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard !part.isEmpty, part.count <= 3, part.allSatisfy(\.isNumber),
                  let octet = UInt32(part), octet <= 255 else { return nil }
            value = value << 8 | octet
        }
        return value
    }

    public static func ipv4String(_ v: UInt32) -> String {
        "\(v >> 24).\(v >> 16 & 0xFF).\(v >> 8 & 0xFF).\(v & 0xFF)"
    }

    public static func mask(fromPrefix prefix: Int) -> UInt32 {
        prefix <= 0 ? 0 : ~UInt32(0) << (32 - prefix)
    }

    public static func prefix(fromMask maskValue: UInt32) -> Int? {
        let n = maskValue.nonzeroBitCount
        return mask(fromPrefix: n) == maskValue ? n : nil
    }

    public static func binary(_ v: UInt32) -> String {
        (0..<4).map { i in
            let octet = v >> ((3 - i) * 8) & 0xFF
            let bits = String(octet, radix: 2)
            return String(repeating: "0", count: 8 - bits.count) + bits
        }
        .joined(separator: ".")
    }

    public static func ipv4(address: String, prefix: Int) throws -> IPv4Info {
        guard let v = ipv4Value(address) else { throw SubnetError.invalidAddress(address) }
        guard (0...32).contains(prefix) else { throw SubnetError.invalidPrefix(String(prefix)) }
        return IPv4Info(address: v, prefix: prefix)
    }

    public static func parseIPv4(_ input: String) throws -> IPv4Info {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if let range = text.range(of: " mask ", options: .caseInsensitive) {
            text = text.replacingCharacters(in: range, with: " ")
        }
        if text.contains("/") {
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { throw SubnetError.invalidInput(input) }
            guard let p = Int(parts[1]), (0...32).contains(p) else { throw SubnetError.invalidPrefix(parts[1]) }
            return try ipv4(address: parts[0], prefix: p)
        }
        let tokens = text.split(whereSeparator: \.isWhitespace).map(String.init)
        if tokens.count == 2 {
            guard let maskValue = ipv4Value(tokens[1]), let p = prefix(fromMask: maskValue) else {
                throw SubnetError.invalidMask(tokens[1])
            }
            return try ipv4(address: tokens[0], prefix: p)
        }
        guard tokens.count == 1 else { throw SubnetError.invalidInput(input) }
        return try ipv4(address: tokens[0], prefix: 32)
    }

    public static func splitCount(from: Int, to: Int) -> UInt64 {
        guard to > from, to <= 32, from >= 0 else { return 0 }
        return UInt64(1) << (to - from)
    }

    public static func split(_ info: IPv4Info, to targetPrefix: Int, cap: Int = 256) -> [IPv4Info] {
        guard targetPrefix > info.prefix, targetPrefix <= 32 else { return [] }
        let total = splitCount(from: info.prefix, to: targetPrefix)
        let shown = Int(min(total, UInt64(cap)))
        let step: UInt32 = targetPrefix == 32 ? 1 : 1 << (32 - targetPrefix)
        var result: [IPv4Info] = []
        result.reserveCapacity(shown)
        var base = info.network
        for _ in 0..<shown {
            result.append(IPv4Info(address: base, prefix: targetPrefix))
            let (next, overflow) = base.addingReportingOverflow(step)
            if overflow { break }
            base = next
        }
        return result
    }

    // MARK: - IPv6

    public static func ipv6Groups(_ input: String) -> [UInt16]? {
        var s = input
        if let percent = s.firstIndex(of: "%") { s = String(s[..<percent]) }
        guard !s.isEmpty else { return nil }

        // An embedded dotted-quad is only valid as the final token of the whole
        // address, i.e. in the only chunk (no "::") or in the right-hand chunk.
        func chunk(_ part: String, allowEmbeddedIPv4: Bool) -> [UInt16]? {
            if part.isEmpty { return [] }
            let tokens = part.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
            var groups: [UInt16] = []
            for (i, token) in tokens.enumerated() {
                if token.contains(".") {
                    guard allowEmbeddedIPv4, i == tokens.count - 1, let v4 = ipv4Value(token) else { return nil }
                    groups.append(UInt16(v4 >> 16))
                    groups.append(UInt16(v4 & 0xFFFF))
                } else {
                    guard (1...4).contains(token.count), token.allSatisfy(\.isHexDigit),
                          let v = UInt16(token, radix: 16) else { return nil }
                    groups.append(v)
                }
            }
            return groups
        }

        let parts = s.components(separatedBy: "::")
        if parts.count == 1 {
            guard let g = chunk(parts[0], allowEmbeddedIPv4: true), g.count == 8 else { return nil }
            return g
        }
        guard parts.count == 2,
              let left = chunk(parts[0], allowEmbeddedIPv4: false),
              let right = chunk(parts[1], allowEmbeddedIPv4: true) else { return nil }
        let fill = 8 - left.count - right.count
        guard fill >= 1 else { return nil }
        return left + Array(repeating: 0, count: fill) + right
    }

    public static func parseIPv6(_ input: String) throws -> IPv6Info {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var addressPart = text
        var prefix = 128
        if text.contains("/") {
            let parts = text.split(separator: "/", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { throw SubnetError.invalidInput(input) }
            guard let p = Int(parts[1]), (0...128).contains(p) else { throw SubnetError.invalidPrefix(parts[1]) }
            addressPart = parts[0]
            prefix = p
        }
        guard let groups = ipv6Groups(addressPart) else { throw SubnetError.invalidAddress(addressPart) }
        return IPv6Info(groups: groups, prefix: prefix)
    }

    public static func canonical(_ groups: [UInt16]) -> String {
        if Array(groups[0..<5]) == [0, 0, 0, 0, 0], groups[5] == 0xFFFF {
            let v4 = UInt32(groups[6]) << 16 | UInt32(groups[7])
            return "::ffff:" + ipv4String(v4)
        }
        var bestStart = -1
        var bestLen = 0
        var i = 0
        while i < 8 {
            if groups[i] == 0 {
                var j = i
                while j < 8, groups[j] == 0 { j += 1 }
                if j - i > bestLen { bestLen = j - i; bestStart = i }
                i = j
            } else {
                i += 1
            }
        }
        let hex = groups.map { String($0, radix: 16) }
        guard bestLen >= 2 else { return hex.joined(separator: ":") }
        let left = hex[0..<bestStart].joined(separator: ":")
        let right = hex[(bestStart + bestLen)...].joined(separator: ":")
        return left + "::" + right
    }

    public static func expanded(_ groups: [UInt16]) -> String {
        groups.map { String(format: "%04x", $0) }.joined(separator: ":")
    }

    static func value128(_ groups: [UInt16]) -> (high: UInt64, low: UInt64) {
        var high: UInt64 = 0
        var low: UInt64 = 0
        for i in 0..<4 { high = high << 16 | UInt64(groups[i]) }
        for i in 4..<8 { low = low << 16 | UInt64(groups[i]) }
        return (high, low)
    }

    static func groups128(high: UInt64, low: UInt64) -> [UInt16] {
        var result: [UInt16] = []
        result.reserveCapacity(8)
        for i in 0..<4 {
            let shift = (3 - i) * 16
            result.append(UInt16(truncatingIfNeeded: high >> shift))
        }
        for i in 0..<4 {
            let shift = (3 - i) * 16
            result.append(UInt16(truncatingIfNeeded: low >> shift))
        }
        return result
    }

    static func mask128(prefix: Int) -> (high: UInt64, low: UInt64) {
        if prefix <= 0 { return (0, 0) }
        if prefix <= 64 { return (~UInt64(0) << (64 - prefix), 0) }
        return (~0, ~UInt64(0) << (128 - prefix))
    }

    public static func powerOfTwoDecimal(_ exponent: Int) -> String {
        var digits = [1]
        for _ in 0..<max(0, exponent) {
            var carry = 0
            for i in digits.indices {
                let v = digits[i] * 2 + carry
                digits[i] = v % 10
                carry = v / 10
            }
            if carry > 0 { digits.append(carry) }
        }
        return digits.reversed().map(String.init).joined()
    }

    // MARK: - Common

    public static func parse(_ input: String) throws -> ParsedSubnet {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SubnetError.invalidInput(input) }
        if trimmed.contains(":") { return .v6(try parseIPv6(trimmed)) }
        return .v4(try parseIPv4(trimmed))
    }

    public static func contains(_ outerInput: String, _ innerInput: String) throws -> Bool {
        let outer = try parse(outerInput)
        let inner = try parse(innerInput)
        switch (outer, inner) {
        case let (.v4(o), .v4(i)):
            return o.prefix <= i.prefix && (i.address & o.netmask) == o.network
        case let (.v6(o), .v6(i)):
            guard o.prefix <= i.prefix else { return false }
            let m = mask128(prefix: o.prefix)
            let ov = value128(o.groups)
            let iv = value128(i.groups)
            return iv.high & m.high == ov.high & m.high && iv.low & m.low == ov.low & m.low
        default:
            throw SubnetError.mixedFamilies
        }
    }
}
