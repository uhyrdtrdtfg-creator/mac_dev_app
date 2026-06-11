import Foundation

// MARK: - Limits

enum JSONTreeLimits {
    /// Documents larger than this fall back to formatted-text rendering.
    static let maxDocumentBytes = 2 * 1024 * 1024
    /// Documents producing more nodes than this fall back to formatted-text rendering.
    static let maxNodeCount = 20_000
    /// Maximum children rendered per node; the remainder is shown as a "+N more" row.
    static let maxChildrenPerNode = 1_000
}

// MARK: - Value model

struct JSONMember: Equatable, Sendable {
    let key: String
    let value: JSONValue
}

indirect enum JSONValue: Equatable, Sendable {
    case string(String)
    /// Original number lexeme from the document (e.g. "1e3", "0.10").
    case number(String)
    case bool(Bool)
    case null
    case object([JSONMember])
    case array([JSONValue])

    var isContainer: Bool {
        switch self {
        case .object, .array: true
        default: false
        }
    }

    var childCount: Int {
        switch self {
        case .object(let members): members.count
        case .array(let items): items.count
        default: 0
        }
    }

    /// Raw scalar text (string content unquoted, number lexeme, true/false, null).
    var scalarText: String? {
        switch self {
        case .string(let s): s
        case .number(let lexeme): lexeme
        case .bool(let b): b ? "true" : "false"
        case .null: "null"
        case .object, .array: nil
        }
    }

    /// Pretty-printed JSON preserving key order.
    func prettyPrinted(indentLevel: Int = 0) -> String {
        let pad = String(repeating: "  ", count: indentLevel)
        let childPad = String(repeating: "  ", count: indentLevel + 1)
        switch self {
        case .string(let s): return JSONValue.quote(s)
        case .number(let lexeme): return lexeme
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .object(let members):
            if members.isEmpty { return "{}" }
            let inner = members.map { "\(childPad)\(JSONValue.quote($0.key)): \($0.value.prettyPrinted(indentLevel: indentLevel + 1))" }.joined(separator: ",\n")
            return "{\n\(inner)\n\(pad)}"
        case .array(let items):
            if items.isEmpty { return "[]" }
            let inner = items.map { "\(childPad)\($0.prettyPrinted(indentLevel: indentLevel + 1))" }.joined(separator: ",\n")
            return "[\n\(inner)\n\(pad)]"
        }
    }

    static func quote(_ s: String) -> String {
        var out = "\""
        for scalar in s.unicodeScalars {
            switch scalar {
            case "\"": out += "\\\""
            case "\\": out += "\\\\"
            case "\n": out += "\\n"
            case "\r": out += "\\r"
            case "\t": out += "\\t"
            case let c where c.value < 0x20: out += String(format: "\\u%04X", c.value)
            default: out.unicodeScalars.append(scalar)
            }
        }
        return out + "\""
    }
}

// MARK: - Parser (preserves key order and number lexemes)

enum JSONParseError: Error, Equatable {
    case syntax(offset: Int)
    case depthExceeded
}

struct JSONValueParser {
    private let bytes: [UInt8]
    private var i = 0
    private static let maxDepth = 512

    static func parse(_ text: String) throws -> JSONValue {
        var parser = JSONValueParser(bytes: Array(text.utf8))
        parser.skipWhitespace()
        let value = try parser.parseValue(depth: 0)
        parser.skipWhitespace()
        guard parser.i == parser.bytes.count else { throw JSONParseError.syntax(offset: parser.i) }
        return value
    }

    private mutating func skipWhitespace() {
        while i < bytes.count, bytes[i] == 0x20 || bytes[i] == 0x09 || bytes[i] == 0x0A || bytes[i] == 0x0D { i += 1 }
    }

    private mutating func parseValue(depth: Int) throws -> JSONValue {
        guard depth < Self.maxDepth else { throw JSONParseError.depthExceeded }
        guard i < bytes.count else { throw JSONParseError.syntax(offset: i) }
        switch bytes[i] {
        case UInt8(ascii: "{"): return try parseObject(depth: depth)
        case UInt8(ascii: "["): return try parseArray(depth: depth)
        case UInt8(ascii: "\""): return .string(try parseString())
        case UInt8(ascii: "t"): try expect("true"); return .bool(true)
        case UInt8(ascii: "f"): try expect("false"); return .bool(false)
        case UInt8(ascii: "n"): try expect("null"); return .null
        default: return .number(try parseNumberLexeme())
        }
    }

    private mutating func expect(_ literal: String) throws {
        for b in literal.utf8 {
            guard i < bytes.count, bytes[i] == b else { throw JSONParseError.syntax(offset: i) }
            i += 1
        }
    }

    private mutating func parseObject(depth: Int) throws -> JSONValue {
        i += 1 // consume {
        var members: [JSONMember] = []
        skipWhitespace()
        if i < bytes.count, bytes[i] == UInt8(ascii: "}") { i += 1; return .object(members) }
        while true {
            skipWhitespace()
            guard i < bytes.count, bytes[i] == UInt8(ascii: "\"") else { throw JSONParseError.syntax(offset: i) }
            let key = try parseString()
            skipWhitespace()
            guard i < bytes.count, bytes[i] == UInt8(ascii: ":") else { throw JSONParseError.syntax(offset: i) }
            i += 1
            skipWhitespace()
            members.append(JSONMember(key: key, value: try parseValue(depth: depth + 1)))
            skipWhitespace()
            guard i < bytes.count else { throw JSONParseError.syntax(offset: i) }
            if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
            if bytes[i] == UInt8(ascii: "}") { i += 1; return .object(members) }
            throw JSONParseError.syntax(offset: i)
        }
    }

    private mutating func parseArray(depth: Int) throws -> JSONValue {
        i += 1 // consume [
        var items: [JSONValue] = []
        skipWhitespace()
        if i < bytes.count, bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
        while true {
            skipWhitespace()
            items.append(try parseValue(depth: depth + 1))
            skipWhitespace()
            guard i < bytes.count else { throw JSONParseError.syntax(offset: i) }
            if bytes[i] == UInt8(ascii: ",") { i += 1; continue }
            if bytes[i] == UInt8(ascii: "]") { i += 1; return .array(items) }
            throw JSONParseError.syntax(offset: i)
        }
    }

    private mutating func parseString() throws -> String {
        i += 1 // consume opening quote
        var out: [UInt8] = []
        while i < bytes.count {
            let b = bytes[i]
            if b == UInt8(ascii: "\"") { i += 1; return String(decoding: out, as: UTF8.self) }
            if b == UInt8(ascii: "\\") {
                i += 1
                guard i < bytes.count else { throw JSONParseError.syntax(offset: i) }
                switch bytes[i] {
                case UInt8(ascii: "\""): out.append(UInt8(ascii: "\"")); i += 1
                case UInt8(ascii: "\\"): out.append(UInt8(ascii: "\\")); i += 1
                case UInt8(ascii: "/"): out.append(UInt8(ascii: "/")); i += 1
                case UInt8(ascii: "b"): out.append(0x08); i += 1
                case UInt8(ascii: "f"): out.append(0x0C); i += 1
                case UInt8(ascii: "n"): out.append(0x0A); i += 1
                case UInt8(ascii: "r"): out.append(0x0D); i += 1
                case UInt8(ascii: "t"): out.append(0x09); i += 1
                case UInt8(ascii: "u"):
                    i += 1
                    let unit = try parseHex4()
                    var scalarValue = UInt32(unit)
                    if (0xD800...0xDBFF).contains(unit), i + 1 < bytes.count, bytes[i] == UInt8(ascii: "\\"), bytes[i + 1] == UInt8(ascii: "u") {
                        i += 2
                        let low = try parseHex4()
                        if (0xDC00...0xDFFF).contains(low) {
                            scalarValue = 0x10000 + (UInt32(unit - 0xD800) << 10) + UInt32(low - 0xDC00)
                        }
                    }
                    let scalar = Unicode.Scalar(scalarValue) ?? Unicode.Scalar(0xFFFD)!
                    out.append(contentsOf: Array(String(scalar).utf8))
                default: throw JSONParseError.syntax(offset: i)
                }
            } else {
                out.append(b)
                i += 1
            }
        }
        throw JSONParseError.syntax(offset: i)
    }

    private mutating func parseHex4() throws -> UInt16 {
        guard i + 4 <= bytes.count else { throw JSONParseError.syntax(offset: i) }
        var value: UInt16 = 0
        for _ in 0..<4 {
            let b = bytes[i]
            let digit: UInt16
            switch b {
            case UInt8(ascii: "0")...UInt8(ascii: "9"): digit = UInt16(b - UInt8(ascii: "0"))
            case UInt8(ascii: "a")...UInt8(ascii: "f"): digit = UInt16(b - UInt8(ascii: "a") + 10)
            case UInt8(ascii: "A")...UInt8(ascii: "F"): digit = UInt16(b - UInt8(ascii: "A") + 10)
            default: throw JSONParseError.syntax(offset: i)
            }
            value = value << 4 | digit
            i += 1
        }
        return value
    }

    private mutating func parseNumberLexeme() throws -> String {
        let start = i
        if i < bytes.count, bytes[i] == UInt8(ascii: "-") { i += 1 }
        var digits = 0
        while i < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[i]) { i += 1; digits += 1 }
        guard digits > 0 else { throw JSONParseError.syntax(offset: i) }
        if i < bytes.count, bytes[i] == UInt8(ascii: ".") {
            i += 1
            while i < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[i]) { i += 1 }
        }
        if i < bytes.count, bytes[i] == UInt8(ascii: "e") || bytes[i] == UInt8(ascii: "E") {
            i += 1
            if i < bytes.count, bytes[i] == UInt8(ascii: "+") || bytes[i] == UInt8(ascii: "-") { i += 1 }
            while i < bytes.count, (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[i]) { i += 1 }
        }
        return String(decoding: bytes[start..<i], as: UTF8.self)
    }
}

// MARK: - Tree node

struct JSONTreeNode: Identifiable, Sendable {
    /// Display label: "$" for the root, the object key, or "[index]" for array elements.
    let key: String
    /// JSONPath of this node, e.g. $.items[2].name or $["a b"].
    let path: String
    let value: JSONValue
    /// nil for scalars; capped at JSONTreeLimits.maxChildrenPerNode for containers.
    let children: [JSONTreeNode]?
    /// Number of children omitted from `children` due to the per-node cap.
    let omittedChildren: Int

    var id: String { path }
    var isContainer: Bool { children != nil }
    /// Total child count before the per-node cap.
    var totalChildCount: Int { value.childCount }
}

enum JSONTreeOutcome: Sendable {
    case tree(root: JSONTreeNode, nodeCount: Int)
    case documentTooLarge
    case tooManyNodes
    case invalid
}

enum JSONTreeModel {
    static func build(jsonString: String) -> JSONTreeOutcome {
        guard jsonString.utf8.count <= JSONTreeLimits.maxDocumentBytes else { return .documentTooLarge }
        guard let value = try? JSONValueParser.parse(jsonString) else { return .invalid }
        var budget = JSONTreeLimits.maxNodeCount
        guard let root = makeNode(key: "$", path: "$", value: value, budget: &budget) else { return .tooManyNodes }
        return .tree(root: root, nodeCount: JSONTreeLimits.maxNodeCount - budget)
    }

    private static func makeNode(key: String, path: String, value: JSONValue, budget: inout Int) -> JSONTreeNode? {
        budget -= 1
        guard budget >= 0 else { return nil }

        switch value {
        case .object(let members):
            var children: [JSONTreeNode] = []
            children.reserveCapacity(min(members.count, JSONTreeLimits.maxChildrenPerNode))
            for member in members.prefix(JSONTreeLimits.maxChildrenPerNode) {
                guard let child = makeNode(key: member.key, path: childPath(of: path, key: member.key), value: member.value, budget: &budget) else { return nil }
                children.append(child)
            }
            return JSONTreeNode(key: key, path: path, value: value, children: children, omittedChildren: max(0, members.count - JSONTreeLimits.maxChildrenPerNode))
        case .array(let items):
            var children: [JSONTreeNode] = []
            children.reserveCapacity(min(items.count, JSONTreeLimits.maxChildrenPerNode))
            for (index, item) in items.prefix(JSONTreeLimits.maxChildrenPerNode).enumerated() {
                guard let child = makeNode(key: "[\(index)]", path: childPath(of: path, index: index), value: item, budget: &budget) else { return nil }
                children.append(child)
            }
            return JSONTreeNode(key: key, path: path, value: value, children: children, omittedChildren: max(0, items.count - JSONTreeLimits.maxChildrenPerNode))
        default:
            return JSONTreeNode(key: key, path: path, value: value, children: nil, omittedChildren: 0)
        }
    }

    // MARK: JSONPath

    static func childPath(of parent: String, key: String) -> String {
        if isIdentifier(key) { return parent + "." + key }
        let escaped = key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return parent + "[\"" + escaped + "\"]"
    }

    static func childPath(of parent: String, index: Int) -> String {
        parent + "[\(index)]"
    }

    private static func isIdentifier(_ key: String) -> Bool {
        guard let first = key.unicodeScalars.first else { return false }
        func isAlpha(_ c: Unicode.Scalar) -> Bool {
            ("a"..."z").contains(c) || ("A"..."Z").contains(c) || c == "_" || c == "$"
        }
        guard isAlpha(first) else { return false }
        return key.unicodeScalars.dropFirst().allSatisfy { isAlpha($0) || ("0"..."9").contains($0) }
    }
}
