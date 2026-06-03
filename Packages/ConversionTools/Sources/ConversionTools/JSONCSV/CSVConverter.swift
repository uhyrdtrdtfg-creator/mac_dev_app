import Foundation

public enum CSVConversionError: Error, LocalizedError {
    case invalidJSON
    case notAnArrayOfObjects
    case emptyCSV

    public var errorDescription: String? {
        switch self {
        case .invalidJSON: "Invalid JSON"
        case .notAnArrayOfObjects: "JSON must be an array of objects (e.g. [{\"a\":1},{\"a\":2}])"
        case .emptyCSV: "CSV is empty"
        }
    }
}

public enum CSVConverter {
    /// Convert a JSON array of objects to CSV. Column order follows first-seen keys.
    public static func jsonToCSV(_ json: String, delimiter: Character = ",") -> Result<String, CSVConversionError> {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(.invalidJSON)
        }

        let rows: [[String: Any]]
        if let array = parsed as? [[String: Any]] {
            rows = array
        } else if let single = parsed as? [String: Any] {
            rows = [single]
        } else {
            return .failure(.notAnArrayOfObjects)
        }

        var columns: [String] = []
        var seen = Set<String>()
        for row in rows {
            for key in row.keys.sorted() where !seen.contains(key) {
                seen.insert(key); columns.append(key)
            }
        }

        let delim = String(delimiter)
        var lines = [columns.map { escapeCSV($0, delimiter: delimiter) }.joined(separator: delim)]
        for row in rows {
            let cells = columns.map { escapeCSV(stringify(row[$0]), delimiter: delimiter) }
            lines.append(cells.joined(separator: delim))
        }
        return .success(lines.joined(separator: "\n"))
    }

    /// Convert CSV (with header row) to a pretty-printed JSON array of objects.
    public static func csvToJSON(_ csv: String, delimiter: Character = ",") -> Result<String, CSVConversionError> {
        let trimmed = csv.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .failure(.emptyCSV) }

        let records = parseCSV(trimmed, delimiter: delimiter)
        guard let header = records.first, records.count >= 1 else { return .failure(.emptyCSV) }

        var objects: [[String: Any]] = []
        for record in records.dropFirst() {
            var obj: [String: Any] = [:]
            for (i, column) in header.enumerated() {
                let value = i < record.count ? record[i] : ""
                obj[column] = inferType(value)
            }
            objects.append(obj)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .withoutEscapingSlashes]) else {
            return .failure(.invalidJSON)
        }
        return .success(String(decoding: data, as: UTF8.self))
    }

    // MARK: - Helpers

    private static func stringify(_ value: Any?) -> String {
        switch value {
        case nil, is NSNull: return ""
        case let s as String: return s
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        case let arr as [Any]: return arr.map { stringify($0) }.joined(separator: "; ")
        default: return "\(value!)"
        }
    }

    private static func inferType(_ value: String) -> Any {
        if value.isEmpty { return NSNull() }
        if value == "true" { return true }
        if value == "false" { return false }
        if let int = Int(value) { return int }
        if let dbl = Double(value) { return dbl }
        return value
    }

    private static func escapeCSV(_ field: String, delimiter: Character) -> String {
        if field.contains(delimiter) || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }

    /// RFC 4180-ish CSV parser handling quoted fields and embedded delimiters/newlines.
    private static func parseCSV(_ text: String, delimiter: Character) -> [[String]] {
        var records: [[String]] = []
        var field = ""
        var record: [String] = []
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 }
                    else { inQuotes = false }
                } else { field.append(c) }
            } else {
                switch c {
                case "\"": inQuotes = true
                case delimiter: record.append(field); field = ""
                case "\n": record.append(field); records.append(record); record = []; field = ""
                case "\r": break
                default: field.append(c)
                }
            }
            i += 1
        }
        record.append(field)
        if record.count > 1 || !record[0].isEmpty { records.append(record) }
        return records
    }
}
