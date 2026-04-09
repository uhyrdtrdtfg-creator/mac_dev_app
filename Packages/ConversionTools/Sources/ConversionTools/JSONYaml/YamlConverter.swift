import Foundation

public enum YamlConverter {
    // MARK: - JSON String → YAML String

    public static func jsonToYaml(_ json: String) -> Result<String, YamlError> {
        guard let data = json.data(using: .utf8) else {
            return .failure(.invalidInput("Invalid UTF-8"))
        }
        do {
            let obj = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            return .success(emitYaml(obj, indent: 0))
        } catch {
            return .failure(.invalidJSON(error.localizedDescription))
        }
    }

    // MARK: - YAML String → JSON String

    public static func yamlToJson(_ yaml: String, prettyPrint: Bool = true) -> Result<String, YamlError> {
        do {
            let parsed = try parseYaml(yaml)
            let options: JSONSerialization.WritingOptions = prettyPrint ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            let data = try JSONSerialization.data(withJSONObject: parsed, options: options)
            guard let result = String(data: data, encoding: .utf8) else {
                return .failure(.invalidInput("Failed to encode JSON"))
            }
            return .success(result)
        } catch let error as YamlError {
            return .failure(error)
        } catch {
            return .failure(.parseError(error.localizedDescription))
        }
    }

    // MARK: - YAML Emitter

    private static func emitYaml(_ value: Any, indent: Int) -> String {
        let prefix = String(repeating: "  ", count: indent)

        if let dict = value as? [String: Any] {
            if dict.isEmpty { return "{}" }
            var lines: [String] = []
            for key in dict.keys.sorted() {
                let val = dict[key]!
                let keyStr = yamlEscapeKey(key)
                if let subDict = val as? [String: Any], !subDict.isEmpty {
                    lines.append("\(prefix)\(keyStr):")
                    lines.append(emitYaml(subDict, indent: indent + 1))
                } else if let arr = val as? [Any], !arr.isEmpty, arr.contains(where: { $0 is [String: Any] || $0 is [Any] }) {
                    lines.append("\(prefix)\(keyStr):")
                    lines.append(emitYaml(arr, indent: indent + 1))
                } else if let arr = val as? [Any], !arr.isEmpty {
                    lines.append("\(prefix)\(keyStr):")
                    lines.append(emitYaml(arr, indent: indent + 1))
                } else {
                    lines.append("\(prefix)\(keyStr): \(emitScalar(val))")
                }
            }
            return lines.joined(separator: "\n")
        }

        if let arr = value as? [Any] {
            if arr.isEmpty { return "[]" }
            var lines: [String] = []
            for item in arr {
                if let subDict = item as? [String: Any], !subDict.isEmpty {
                    let firstKey = subDict.keys.sorted().first!
                    let firstVal = subDict[firstKey]!
                    // First key on same line as dash
                    if let nestedDict = firstVal as? [String: Any], !nestedDict.isEmpty {
                        lines.append("\(prefix)- \(yamlEscapeKey(firstKey)):")
                        lines.append(emitYaml(nestedDict, indent: indent + 2))
                    } else if let nestedArr = firstVal as? [Any], !nestedArr.isEmpty {
                        lines.append("\(prefix)- \(yamlEscapeKey(firstKey)):")
                        lines.append(emitYaml(nestedArr, indent: indent + 2))
                    } else {
                        lines.append("\(prefix)- \(yamlEscapeKey(firstKey)): \(emitScalar(firstVal))")
                    }
                    // Remaining keys indented
                    for key in subDict.keys.sorted().dropFirst() {
                        let val = subDict[key]!
                        let innerPrefix = String(repeating: "  ", count: indent + 1)
                        if let nestedDict = val as? [String: Any], !nestedDict.isEmpty {
                            lines.append("\(innerPrefix)\(yamlEscapeKey(key)):")
                            lines.append(emitYaml(nestedDict, indent: indent + 2))
                        } else if let nestedArr = val as? [Any], !nestedArr.isEmpty {
                            lines.append("\(innerPrefix)\(yamlEscapeKey(key)):")
                            lines.append(emitYaml(nestedArr, indent: indent + 2))
                        } else {
                            lines.append("\(innerPrefix)\(yamlEscapeKey(key)): \(emitScalar(val))")
                        }
                    }
                } else {
                    lines.append("\(prefix)- \(emitScalar(item))")
                }
            }
            return lines.joined(separator: "\n")
        }

        return "\(prefix)\(emitScalar(value))"
    }

    private static func emitScalar(_ value: Any) -> String {
        if value is NSNull { return "null" }
        if let b = value as? Bool { return b ? "true" : "false" }
        if let n = value as? NSNumber {
            // Check if it's actually a boolean (NSNumber wraps bools)
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                return n.boolValue ? "true" : "false"
            }
            if n.doubleValue == Double(n.intValue) && !"\(n)".contains(".") {
                return "\(n.intValue)"
            }
            return "\(n)"
        }
        if let s = value as? String {
            return yamlEscapeString(s)
        }
        if let arr = value as? [Any], arr.isEmpty { return "[]" }
        if let dict = value as? [String: Any], dict.isEmpty { return "{}" }
        return "\(value)"
    }

    private static func yamlEscapeKey(_ key: String) -> String {
        // Quote keys that contain special chars
        if key.isEmpty || key.contains(":") || key.contains("#") || key.contains("{") || key.contains("}") || key.contains("[") || key.contains("]") || key.contains(",") || key.contains("&") || key.contains("*") || key.contains("!") || key.contains("|") || key.contains(">") || key.contains("'") || key.contains("\"") || key.contains("%") || key.contains("@") || key.hasPrefix("- ") || key.hasPrefix("? ") {
            return "\"\(key.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return key
    }

    private static func yamlEscapeString(_ s: String) -> String {
        if s.isEmpty { return "''" }
        // Check if it looks like a YAML special value
        let lower = s.lowercased()
        if lower == "true" || lower == "false" || lower == "null" || lower == "~" || lower == "yes" || lower == "no" || lower == "on" || lower == "off" {
            return "'\(s)'"
        }
        // Check if it's a number
        if Double(s) != nil || Int(s) != nil {
            return "'\(s)'"
        }
        // Check for special characters that need quoting
        if s.contains("\n") || s.contains("\r") || s.contains("\t") || s.contains("\"") || s.contains("\\") {
            let escaped = s.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "\"", with: "\\\"")
                .replacingOccurrences(of: "\n", with: "\\n")
                .replacingOccurrences(of: "\r", with: "\\r")
                .replacingOccurrences(of: "\t", with: "\\t")
            return "\"\(escaped)\""
        }
        if s.contains(": ") || s.contains(" #") || s.hasPrefix("[") || s.hasPrefix("{") || s.hasPrefix("'") || s.hasPrefix("\"") || s.hasPrefix("- ") || s.hasPrefix("? ") || s.hasSuffix(":") || s.hasSuffix(" ") || s.hasPrefix(" ") {
            return "'\(s.replacingOccurrences(of: "'", with: "''"))'"
        }
        return s
    }

    // MARK: - YAML Parser (lightweight)

    private static func parseYaml(_ yaml: String) throws -> Any {
        let lines = yaml.components(separatedBy: "\n")
        var index = 0
        let result = try parseValue(lines: lines, index: &index, baseIndent: -1)
        return result
    }

    private static func parseValue(lines: [String], index: inout Int, baseIndent: Int) throws -> Any {
        skipEmptyAndComments(lines: lines, index: &index)
        guard index < lines.count else { return NSNull() }

        let line = lines[index]
        let indent = lineIndent(line)
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Flow-style inline
        if trimmed.hasPrefix("{") { return try parseInlineMapping(trimmed) }
        if trimmed.hasPrefix("[") { return try parseInlineSequence(trimmed) }

        // Check if it's a sequence item
        if trimmed.hasPrefix("- ") || trimmed == "-" {
            return try parseSequence(lines: lines, index: &index, baseIndent: indent)
        }

        // Check if it's a mapping
        if trimmed.contains(": ") || trimmed.hasSuffix(":") {
            return try parseMapping(lines: lines, index: &index, baseIndent: indent)
        }

        // Scalar
        index += 1
        return parseScalar(trimmed)
    }

    private static func parseMapping(lines: [String], index: inout Int, baseIndent: Int) throws -> [String: Any] {
        var dict: [String: Any] = [:]

        while index < lines.count {
            skipEmptyAndComments(lines: lines, index: &index)
            guard index < lines.count else { break }

            let line = lines[index]
            let indent = lineIndent(line)
            if indent < baseIndent { break }
            if indent > baseIndent && !dict.isEmpty { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { index += 1; continue }
            if trimmed.hasPrefix("- ") { break } // sequence at same level

            guard let colonRange = findKeyColon(trimmed) else {
                index += 1; continue
            }

            let key = unquote(String(trimmed[trimmed.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces))
            let afterColon = String(trimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

            if afterColon.isEmpty {
                // Value on next line(s)
                index += 1
                skipEmptyAndComments(lines: lines, index: &index)
                if index < lines.count {
                    let nextIndent = lineIndent(lines[index])
                    if nextIndent > indent {
                        dict[key] = try parseValue(lines: lines, index: &index, baseIndent: indent)
                    } else {
                        dict[key] = NSNull()
                    }
                } else {
                    dict[key] = NSNull()
                }
            } else if afterColon.hasPrefix("{") || afterColon.hasPrefix("[") {
                dict[key] = afterColon.hasPrefix("{") ? try parseInlineMapping(afterColon) : try parseInlineSequence(afterColon)
                index += 1
            } else {
                dict[key] = parseScalar(afterColon)
                index += 1
            }
        }

        return dict
    }

    private static func parseSequence(lines: [String], index: inout Int, baseIndent: Int) throws -> [Any] {
        var arr: [Any] = []

        while index < lines.count {
            skipEmptyAndComments(lines: lines, index: &index)
            guard index < lines.count else { break }

            let line = lines[index]
            let indent = lineIndent(line)
            if indent < baseIndent { break }
            if indent > baseIndent { break }

            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("- ") || trimmed == "-" else { break }

            let afterDash = trimmed == "-" ? "" : String(trimmed.dropFirst(2))
            let dashTrimmed = afterDash.trimmingCharacters(in: .whitespaces)

            if dashTrimmed.isEmpty {
                index += 1
                skipEmptyAndComments(lines: lines, index: &index)
                if index < lines.count && lineIndent(lines[index]) > indent {
                    arr.append(try parseValue(lines: lines, index: &index, baseIndent: indent))
                } else {
                    arr.append(NSNull())
                }
            } else if dashTrimmed.hasPrefix("{") || dashTrimmed.hasPrefix("[") {
                arr.append(dashTrimmed.hasPrefix("{") ? try parseInlineMapping(dashTrimmed) : try parseInlineSequence(dashTrimmed))
                index += 1
            } else if dashTrimmed.contains(": ") || dashTrimmed.hasSuffix(":") {
                // Inline mapping start after dash
                // First key-value pair
                guard let colonRange = findKeyColon(dashTrimmed) else {
                    arr.append(parseScalar(dashTrimmed))
                    index += 1
                    continue
                }
                let key = unquote(String(dashTrimmed[dashTrimmed.startIndex..<colonRange.lowerBound]).trimmingCharacters(in: .whitespaces))
                let afterColon = String(dashTrimmed[colonRange.upperBound...]).trimmingCharacters(in: .whitespaces)

                var itemDict: [String: Any] = [:]

                if afterColon.isEmpty {
                    index += 1
                    skipEmptyAndComments(lines: lines, index: &index)
                    if index < lines.count && lineIndent(lines[index]) > indent + 2 {
                        itemDict[key] = try parseValue(lines: lines, index: &index, baseIndent: indent + 2)
                    } else {
                        itemDict[key] = NSNull()
                    }
                } else {
                    itemDict[key] = parseScalar(afterColon)
                    index += 1
                }

                // Continue reading mapping at indent+2
                while index < lines.count {
                    skipEmptyAndComments(lines: lines, index: &index)
                    guard index < lines.count else { break }
                    let nextLine = lines[index]
                    let nextIndent = lineIndent(nextLine)
                    let nextTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                    if nextIndent <= indent { break }
                    if nextTrimmed.hasPrefix("- ") { break }
                    guard let nc = findKeyColon(nextTrimmed) else { index += 1; continue }
                    let nk = unquote(String(nextTrimmed[nextTrimmed.startIndex..<nc.lowerBound]).trimmingCharacters(in: .whitespaces))
                    let nv = String(nextTrimmed[nc.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if nv.isEmpty {
                        index += 1
                        if index < lines.count && lineIndent(lines[index]) > nextIndent {
                            itemDict[nk] = try parseValue(lines: lines, index: &index, baseIndent: nextIndent)
                        } else {
                            itemDict[nk] = NSNull()
                        }
                    } else {
                        itemDict[nk] = parseScalar(nv)
                        index += 1
                    }
                }

                arr.append(itemDict)
            } else {
                arr.append(parseScalar(dashTrimmed))
                index += 1
            }
        }

        return arr
    }

    // MARK: - Inline Parsers

    private static func parseInlineMapping(_ s: String) throws -> [String: Any] {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("{") && trimmed.hasSuffix("}") else { throw YamlError.parseError("Invalid inline mapping") }
        let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return [:] }
        // Simple split by comma (doesn't handle nested structures well, but covers common cases)
        var dict: [String: Any] = [:]
        for part in splitTopLevel(inner, separator: ",") {
            let kv = part.trimmingCharacters(in: .whitespaces)
            if let c = kv.firstIndex(of: ":") {
                let k = unquote(String(kv[kv.startIndex..<c]).trimmingCharacters(in: .whitespaces))
                let v = String(kv[kv.index(after: c)...]).trimmingCharacters(in: .whitespaces)
                dict[k] = parseScalar(v)
            }
        }
        return dict
    }

    private static func parseInlineSequence(_ s: String) throws -> [Any] {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("[") && trimmed.hasSuffix("]") else { throw YamlError.parseError("Invalid inline sequence") }
        let inner = String(trimmed.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        if inner.isEmpty { return [] }
        return splitTopLevel(inner, separator: ",").map { parseScalar($0.trimmingCharacters(in: .whitespaces)) }
    }

    // MARK: - Helpers

    private static func parseScalar(_ s: String) -> Any {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == "~" || trimmed.lowercased() == "null" { return NSNull() }
        if trimmed.lowercased() == "true" || trimmed.lowercased() == "yes" || trimmed.lowercased() == "on" { return true }
        if trimmed.lowercased() == "false" || trimmed.lowercased() == "no" || trimmed.lowercased() == "off" { return false }

        // Remove inline comments
        let value = removeInlineComment(trimmed)

        // Quoted string
        let unquoted = unquote(value)
        if unquoted != value { return unquoted }

        // Number
        if let i = Int(value) { return i }
        if let d = Double(value) { return d }

        return value
    }

    private static func unquote(_ s: String) -> String {
        if (s.hasPrefix("\"") && s.hasSuffix("\"")) || (s.hasPrefix("'") && s.hasSuffix("'")) {
            var inner = String(s.dropFirst().dropLast())
            if s.hasPrefix("\"") {
                inner = inner.replacingOccurrences(of: "\\\"", with: "\"")
                    .replacingOccurrences(of: "\\n", with: "\n")
                    .replacingOccurrences(of: "\\t", with: "\t")
                    .replacingOccurrences(of: "\\\\", with: "\\")
            } else {
                inner = inner.replacingOccurrences(of: "''", with: "'")
            }
            return inner
        }
        return s
    }

    private static func lineIndent(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " { count += 1 }
            else { break }
        }
        return count
    }

    private static func skipEmptyAndComments(lines: [String], index: inout Int) {
        while index < lines.count {
            let trimmed = lines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { index += 1 }
            else { break }
        }
    }

    private static func findKeyColon(_ s: String) -> Range<String.Index>? {
        var inSingleQuote = false
        var inDoubleQuote = false
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if c == "'" && !inDoubleQuote { inSingleQuote.toggle() }
            else if c == "\"" && !inSingleQuote { inDoubleQuote.toggle() }
            else if c == ":" && !inSingleQuote && !inDoubleQuote {
                let next = s.index(after: i)
                if next == s.endIndex || s[next] == " " {
                    return i..<next
                }
            }
            i = s.index(after: i)
        }
        return nil
    }

    private static func removeInlineComment(_ s: String) -> String {
        var inQuote = false
        var quoteChar: Character = "\""
        var i = s.startIndex
        while i < s.endIndex {
            let c = s[i]
            if (c == "'" || c == "\"") && !inQuote { inQuote = true; quoteChar = c }
            else if c == quoteChar && inQuote { inQuote = false }
            else if c == "#" && !inQuote {
                if i > s.startIndex {
                    let prev = s.index(before: i)
                    if s[prev] == " " { return String(s[s.startIndex..<prev]).trimmingCharacters(in: .whitespaces) }
                }
            }
            i = s.index(after: i)
        }
        return s
    }

    private static func splitTopLevel(_ s: String, separator: Character) -> [String] {
        var parts: [String] = []
        var current = ""
        var depth = 0
        var inQuote = false
        var quoteChar: Character = "\""
        for c in s {
            if (c == "'" || c == "\"") && !inQuote { inQuote = true; quoteChar = c }
            else if c == quoteChar && inQuote { inQuote = false }
            else if !inQuote {
                if c == "{" || c == "[" { depth += 1 }
                else if c == "}" || c == "]" { depth -= 1 }
                else if c == separator && depth == 0 {
                    parts.append(current)
                    current = ""
                    continue
                }
            }
            current.append(c)
        }
        if !current.isEmpty { parts.append(current) }
        return parts
    }
}

public enum YamlError: Error, LocalizedError {
    case invalidInput(String)
    case invalidJSON(String)
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let msg): "Invalid input: \(msg)"
        case .invalidJSON(let msg): "Invalid JSON: \(msg)"
        case .parseError(let msg): "YAML parse error: \(msg)"
        }
    }
}
