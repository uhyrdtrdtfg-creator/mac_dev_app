import Foundation

public struct JSONPathResult: Sendable {
    public let output: String?
    public let error: String?
}

/// A small JSONPath subset: `$`, `.key`, `["key"]`, `[index]`, `[*]` (wildcard over array/object).
public enum JSONPathQuery {
    public static func query(_ json: String, path: String) -> JSONPathResult {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) else {
            return JSONPathResult(output: nil, error: "Invalid JSON")
        }
        let trimmed = path.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return JSONPathResult(output: nil, error: nil) }

        let tokens: [PathToken]
        do { tokens = try tokenize(trimmed) }
        catch let error as JSONPathError { return JSONPathResult(output: nil, error: error.message) }
        catch { return JSONPathResult(output: nil, error: error.localizedDescription) }

        var current: [Any] = [root]
        for token in tokens {
            var next: [Any] = []
            for node in current {
                next.append(contentsOf: apply(token, to: node))
            }
            current = next
        }

        let result: Any = current.count == 1 ? current[0] : current
        guard JSONSerialization.isValidJSONObject(result) || current.count != 1 else {
            // Single scalar result — render directly.
            return JSONPathResult(output: scalarString(current.first), error: nil)
        }
        if let out = try? JSONSerialization.data(withJSONObject: wrapForSerialization(result), options: [.prettyPrinted, .withoutEscapingSlashes]) {
            return JSONPathResult(output: String(decoding: out, as: UTF8.self), error: nil)
        }
        return JSONPathResult(output: scalarString(result), error: nil)
    }

    private enum PathToken {
        case key(String)
        case index(Int)
        case wildcard
    }

    private struct JSONPathError: Error { let message: String }

    private static func tokenize(_ path: String) throws -> [PathToken] {
        var p = path
        if p.hasPrefix("$") { p.removeFirst() }
        var tokens: [PathToken] = []
        let chars = Array(p)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "." {
                i += 1
                var key = ""
                while i < chars.count, chars[i] != "." && chars[i] != "[" { key.append(chars[i]); i += 1 }
                if key == "*" { tokens.append(.wildcard) }
                else if !key.isEmpty { tokens.append(.key(key)) }
            } else if c == "[" {
                i += 1
                var inner = ""
                while i < chars.count, chars[i] != "]" { inner.append(chars[i]); i += 1 }
                i += 1 // skip ]
                inner = inner.trimmingCharacters(in: .whitespaces)
                if inner == "*" { tokens.append(.wildcard) }
                else if inner.hasPrefix("\"") || inner.hasPrefix("'") {
                    tokens.append(.key(String(inner.dropFirst().dropLast())))
                } else if let idx = Int(inner) {
                    tokens.append(.index(idx))
                } else {
                    throw JSONPathError(message: "Invalid bracket selector: [\(inner)]")
                }
            } else {
                throw JSONPathError(message: "Unexpected character '\(c)' in path")
            }
        }
        return tokens
    }

    private static func apply(_ token: PathToken, to node: Any) -> [Any] {
        switch token {
        case .key(let key):
            if let dict = node as? [String: Any], let v = dict[key] { return [v] }
            return []
        case .index(let idx):
            if let arr = node as? [Any] {
                let real = idx < 0 ? arr.count + idx : idx
                if real >= 0 && real < arr.count { return [arr[real]] }
            }
            return []
        case .wildcard:
            if let arr = node as? [Any] { return arr }
            if let dict = node as? [String: Any] { return dict.keys.sorted().map { dict[$0]! } }
            return []
        }
    }

    private static func wrapForSerialization(_ value: Any) -> Any {
        if JSONSerialization.isValidJSONObject(value) { return value }
        return [value] // wrap scalar in array so serialization succeeds; rendered below otherwise
    }

    private static func scalarString(_ value: Any?) -> String {
        switch value {
        case nil: return "null"
        case let s as String: return "\"\(s)\""
        case let b as Bool: return b ? "true" : "false"
        case let n as NSNumber: return n.stringValue
        default: return "\(value!)"
        }
    }
}
