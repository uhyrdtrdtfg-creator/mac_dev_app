import Foundation

public enum DotenvError: Error, LocalizedError {
    case invalidJSON
    case rootNotObject

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: "Invalid JSON"
        case .rootNotObject: "JSON root must be an object"
        }
    }
}

/// Convert between `.env` / `.properties` / `.ini` and JSON.
/// `[section]` headers produce nested objects; flat `KEY=VALUE` pairs stay top-level.
public enum DotenvConverter {
    public static func toJSON(_ text: String) -> Result<String, DotenvError> {
        var root: [String: Any] = [:]
        var section: String?

        for rawLine in text.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty || line.hasPrefix("#") || line.hasPrefix(";") { continue }

            if line.hasPrefix("[") && line.hasSuffix("]") {
                section = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                if let s = section, root[s] == nil { root[s] = [String: Any]() }
                continue
            }

            let separatorIndex = line.firstIndex(of: "=") ?? line.firstIndex(of: ":")
            guard let sep = separatorIndex else { continue }
            var key = String(line[..<sep]).trimmingCharacters(in: .whitespaces)
            if key.hasPrefix("export ") { key = String(key.dropFirst(7)).trimmingCharacters(in: .whitespaces) }
            let rawValue = String(line[line.index(after: sep)...]).trimmingCharacters(in: .whitespaces)
            let value = inferValue(unquote(rawValue))

            if let s = section {
                var dict = root[s] as? [String: Any] ?? [:]
                dict[key] = value
                root[s] = dict
            } else {
                root[key] = value
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else {
            return .failure(.invalidJSON)
        }
        return .success(String(decoding: data, as: UTF8.self))
    }

    public static func fromJSON(_ json: String) -> Result<String, DotenvError> {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(.invalidJSON)
        }
        guard let dict = obj as? [String: Any] else { return .failure(.rootNotObject) }

        var flat = ""
        var sections = ""
        for key in dict.keys.sorted() {
            let value = dict[key]!
            if let nested = value as? [String: Any] {
                sections += "\n[\(key)]\n"
                for k in nested.keys.sorted() {
                    sections += "\(k)=\(scalarString(nested[k]!))\n"
                }
            } else {
                flat += "\(key)=\(scalarString(value))\n"
            }
        }
        return .success((flat + sections).trimmingCharacters(in: .newlines))
    }

    // MARK: - Helpers

    private static func unquote(_ value: String) -> String {
        if (value.hasPrefix("\"") && value.hasSuffix("\"")) || (value.hasPrefix("'") && value.hasSuffix("'")), value.count >= 2 {
            return String(value.dropFirst().dropLast())
        }
        return value
    }

    private static func inferValue(_ value: String) -> Any {
        if value == "true" { return true }
        if value == "false" { return false }
        if let int = Int(value) { return int }
        if let dbl = Double(value) { return dbl }
        return value
    }

    private static func scalarString(_ value: Any) -> String {
        if let n = value as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        if let s = value as? String {
            return s.contains(" ") || s.contains("#") ? "\"\(s)\"" : s
        }
        return "\(value)"
    }
}
