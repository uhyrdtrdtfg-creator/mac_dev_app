import Foundation

public enum TOMLConversionError: Error, LocalizedError {
    case invalidJSON
    case invalidTOML(String)
    case unsupportedRoot

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: "Invalid JSON"
        case .invalidTOML(let m): "Invalid TOML: \(m)"
        case .unsupportedRoot: "Root must be a JSON object"
        }
    }
}

/// A pragmatic TOML subset: scalars, nested tables, inline scalar arrays, and arrays of tables.
public enum TOMLConverter {
    public static func jsonToTOML(_ json: String) -> Result<String, TOMLConversionError> {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(.invalidJSON)
        }
        guard let dict = obj as? [String: Any] else { return .failure(.unsupportedRoot) }
        var out = ""
        emit(dict, path: [], into: &out)
        return .success(out.trimmingCharacters(in: .newlines))
    }

    public static func tomlToJSON(_ toml: String) -> Result<String, TOMLConversionError> {
        do {
            let root = try parse(toml)
            let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
            return .success(String(decoding: data, as: UTF8.self))
        } catch let error as TOMLConversionError {
            return .failure(error)
        } catch {
            return .failure(.invalidTOML(error.localizedDescription))
        }
    }

    // MARK: - Emit (JSON -> TOML)

    private static func emit(_ dict: [String: Any], path: [String], into out: inout String) {
        let keys = dict.keys.sorted()
        // Scalars and scalar arrays first.
        for key in keys {
            let value = dict[key]!
            if isScalar(value) || isScalarArray(value) {
                out += "\(key) = \(formatValue(value))\n"
            }
        }
        // Then nested tables / arrays of tables.
        for key in keys {
            let value = dict[key]!
            if let nested = value as? [String: Any] {
                let newPath = path + [key]
                out += "\n[\(newPath.joined(separator: "."))]\n"
                emit(nested, path: newPath, into: &out)
            } else if let arr = value as? [Any], arr.allSatisfy({ $0 is [String: Any] }), !arr.isEmpty {
                let newPath = path + [key]
                for element in arr {
                    out += "\n[[\(newPath.joined(separator: "."))]]\n"
                    emit(element as! [String: Any], path: newPath, into: &out)
                }
            }
        }
    }

    private static func isScalar(_ v: Any) -> Bool {
        v is String || v is Bool || v is NSNumber || v is Int || v is Double
    }

    private static func isScalarArray(_ v: Any) -> Bool {
        guard let arr = v as? [Any] else { return false }
        return arr.allSatisfy { isScalar($0) }
    }

    private static func formatValue(_ v: Any) -> String {
        if let n = v as? NSNumber {
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        }
        if let s = v as? String {
            return "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        if let arr = v as? [Any] {
            return "[" + arr.map { formatValue($0) }.joined(separator: ", ") + "]"
        }
        return "\"\(v)\""
    }

    // MARK: - Parse (TOML -> JSON)

    private static func parse(_ toml: String) throws -> [String: Any] {
        var root: [String: Any] = [:]
        var currentPath: [String] = []
        var arrayTablePaths = Set<String>()

        for rawLine in toml.components(separatedBy: .newlines) {
            let line = stripComment(rawLine).trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line.hasPrefix("[[") && line.hasSuffix("]]") {
                let name = String(line.dropFirst(2).dropLast(2)).trimmingCharacters(in: .whitespaces)
                currentPath = name.split(separator: ".").map(String.init)
                arrayTablePaths.insert(name)
                appendArrayTable(&root, path: currentPath)
            } else if line.hasPrefix("[") && line.hasSuffix("]") {
                let name = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                currentPath = name.split(separator: ".").map(String.init)
                ensureTable(&root, path: currentPath)
            } else if let eq = line.firstIndex(of: "=") {
                let key = String(line[..<eq]).trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                let valueStr = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
                let value = try parseValue(valueStr)
                setValue(&root, path: currentPath, key: key, value: value, arrayTablePaths: arrayTablePaths)
            } else {
                throw TOMLConversionError.invalidTOML("Cannot parse line: \(line)")
            }
        }
        return root
    }

    private static func stripComment(_ line: String) -> String {
        var inString = false
        var result = ""
        for c in line {
            if c == "\"" { inString.toggle() }
            if c == "#" && !inString { break }
            result.append(c)
        }
        return result
    }

    private static func parseValue(_ str: String) throws -> Any {
        if str.hasPrefix("[") && str.hasSuffix("]") {
            let inner = String(str.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
            if inner.isEmpty { return [Any]() }
            return try splitArray(inner).map { try parseValue($0.trimmingCharacters(in: .whitespaces)) }
        }
        if (str.hasPrefix("\"") && str.hasSuffix("\"")) || (str.hasPrefix("'") && str.hasSuffix("'")) {
            return String(str.dropFirst().dropLast())
                .replacingOccurrences(of: "\\\"", with: "\"")
                .replacingOccurrences(of: "\\\\", with: "\\")
        }
        if str == "true" { return true }
        if str == "false" { return false }
        if let int = Int(str) { return int }
        if let dbl = Double(str) { return dbl }
        return str
    }

    private static func splitArray(_ inner: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var inString = false
        var current = ""
        for c in inner {
            if c == "\"" { inString.toggle() }
            if !inString {
                if c == "[" { depth += 1 }
                if c == "]" { depth -= 1 }
                if c == "," && depth == 0 { parts.append(current); current = ""; continue }
            }
            current.append(c)
        }
        if !current.trimmingCharacters(in: .whitespaces).isEmpty { parts.append(current) }
        return parts
    }

    // MARK: - Nested mutation helpers

    private static func ensureTable(_ root: inout [String: Any], path: [String]) {
        guard !path.isEmpty else { return }
        var dict = root[path[0]] as? [String: Any] ?? [:]
        if path.count == 1 {
            root[path[0]] = dict
        } else {
            ensureTableRec(&dict, path: Array(path.dropFirst()))
            root[path[0]] = dict
        }
    }

    private static func ensureTableRec(_ dict: inout [String: Any], path: [String]) {
        guard !path.isEmpty else { return }
        var child = dict[path[0]] as? [String: Any] ?? [:]
        if path.count > 1 { ensureTableRec(&child, path: Array(path.dropFirst())) }
        dict[path[0]] = child
    }

    private static func appendArrayTable(_ root: inout [String: Any], path: [String]) {
        modify(&root, path: path) { container in
            guard let key = path.last else { return }
            var arr = container[key] as? [Any] ?? []
            arr.append([String: Any]())
            container[key] = arr
        }
    }

    private static func setValue(_ root: inout [String: Any], path: [String], key: String, value: Any, arrayTablePaths: Set<String>) {
        if path.isEmpty {
            root[key] = value
            return
        }
        let pathName = path.joined(separator: ".")
        modify(&root, path: path) { container in
            guard let last = path.last else { return }
            if arrayTablePaths.contains(pathName), var arr = container[last] as? [Any], var element = arr.last as? [String: Any] {
                element[key] = value
                arr[arr.count - 1] = element
                container[last] = arr
            } else {
                var table = container[last] as? [String: Any] ?? [:]
                table[key] = value
                container[last] = table
            }
        }
    }

    /// Navigate to the parent dictionary of `path` and apply `body` to it.
    private static func modify(_ root: inout [String: Any], path: [String], body: (inout [String: Any]) -> Void) {
        if path.count == 1 {
            body(&root)
            return
        }
        let head = path[0]
        var child = root[head] as? [String: Any] ?? [:]
        modify(&child, path: Array(path.dropFirst()), body: body)
        root[head] = child
    }
}
