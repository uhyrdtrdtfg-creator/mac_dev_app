import Foundation

public struct SQLResultTable: Sendable {
    public let columns: [String]
    public let rows: [[String]]   // raw cell text; "NULL" preserved verbatim
}

public enum SQLResultConverter {
    /// Parse a MySQL/psql style result. Supports the ASCII bordered table
    /// (`+----+` / `| ... |`) and tab-separated (`mysql -B`) output.
    public static func parse(_ text: String) -> SQLResultTable? {
        if let bordered = parseBordered(text) { return bordered }
        return parseTabSeparated(text)
    }

    /// Best-effort extraction of the table name from a pasted query
    /// (`FROM x`, `UPDATE x`, `INSERT INTO x`). Returns nil if none found.
    public static func parseTableName(_ text: String) -> String? {
        let patterns = [
            "(?i)\\binsert\\s+into\\s+[`\"']?([A-Za-z0-9_$.]+)",
            "(?i)\\bupdate\\s+[`\"']?([A-Za-z0-9_$.]+)",
            "(?i)\\bfrom\\s+[`\"']?([A-Za-z0-9_$.]+)"
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let ns = text as NSString
            if let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)),
               match.numberOfRanges > 1 {
                let name = ns.substring(with: match.range(at: 1))
                // Strip a leading db qualifier: db.table -> table is NOT done; keep as-is.
                if !name.isEmpty { return name }
            }
        }
        return nil
    }

    // MARK: - Bordered table

    private static func parseBordered(_ text: String) -> SQLResultTable? {
        let dataLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("|") }
        guard dataLines.count >= 1 else { return nil }

        let parsed = dataLines.map(splitPipeRow)
        guard let header = parsed.first, !header.isEmpty else { return nil }
        let rows = Array(parsed.dropFirst()).filter { $0.count == header.count }
        return SQLResultTable(columns: header, rows: rows)
    }

    private static func splitPipeRow(_ line: String) -> [String] {
        var cells = line.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        // Drop the empty cells produced by the leading/trailing pipes.
        if cells.first == "" { cells.removeFirst() }
        if cells.last == "" { cells.removeLast() }
        return cells
    }

    // MARK: - Tab separated

    private static func parseTabSeparated(_ text: String) -> SQLResultTable? {
        let lines = text.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard lines.count >= 2, lines[0].contains("\t") else { return nil }
        let header = lines[0].components(separatedBy: "\t")
        let rows = lines.dropFirst().map { $0.components(separatedBy: "\t") }.filter { $0.count == header.count }
        return SQLResultTable(columns: header, rows: Array(rows))
    }

    // MARK: - CSV

    public static func toCSV(_ table: SQLResultTable, delimiter: Character = ",") -> String {
        let delim = String(delimiter)
        var lines = [table.columns.map { escapeCSV($0, delimiter: delimiter) }.joined(separator: delim)]
        for row in table.rows {
            lines.append(row.map { escapeCSV(csvValue($0), delimiter: delimiter) }.joined(separator: delim))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - INSERT

    public static func toInsert(_ table: SQLResultTable, tableName: String) -> String {
        guard !table.rows.isEmpty else { return "" }
        let name = quoteIdentifier(tableName)
        let cols = table.columns.map(quoteIdentifier).joined(separator: ", ")
        let valueRows = table.rows.map { row in
            "(" + row.map(sqlValue).joined(separator: ", ") + ")"
        }
        return "INSERT INTO \(name) (\(cols)) VALUES\n" + valueRows.joined(separator: ",\n") + ";"
    }

    // MARK: - UPDATE

    public static func toUpdate(_ table: SQLResultTable, tableName: String, keyColumn: String) -> String {
        guard let keyIndex = table.columns.firstIndex(of: keyColumn) else { return "" }
        let name = quoteIdentifier(tableName)
        var statements: [String] = []
        for row in table.rows {
            guard row.indices.contains(keyIndex) else { continue }
            let assignments = zip(table.columns, row).enumerated()
                .filter { $0.offset != keyIndex }
                .map { "\(quoteIdentifier($0.element.0)) = \(sqlValue($0.element.1))" }
                .joined(separator: ", ")
            let whereClause = "\(quoteIdentifier(keyColumn)) = \(sqlValue(row[keyIndex]))"
            statements.append("UPDATE \(name) SET \(assignments) WHERE \(whereClause);")
        }
        return statements.joined(separator: "\n")
    }

    // MARK: - Value helpers

    private static func csvValue(_ cell: String) -> String {
        cell == "NULL" ? "" : cell
    }

    private static func sqlValue(_ cell: String) -> String {
        if cell == "NULL" { return "NULL" }
        if isNumeric(cell) { return cell }
        let escaped = cell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    private static func isNumeric(_ s: String) -> Bool {
        guard !s.isEmpty else { return false }
        if Int(s) != nil { return true }
        // Accept decimals but not things like "0123" identifiers or values with leading zeros that matter.
        if let _ = Double(s), s.range(of: "^-?(0|[1-9][0-9]*)(\\.[0-9]+)?$", options: .regularExpression) != nil {
            return true
        }
        return false
    }

    private static func quoteIdentifier(_ name: String) -> String {
        "`\(name.replacingOccurrences(of: "`", with: "``"))`"
    }

    private static func escapeCSV(_ field: String, delimiter: Character) -> String {
        if field.contains(delimiter) || field.contains("\"") || field.contains("\n") {
            return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return field
    }
}
