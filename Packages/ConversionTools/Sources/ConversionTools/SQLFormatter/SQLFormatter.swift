import Foundation

public enum SQLFormatter {
    private static let newlineKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "GROUP BY", "ORDER BY", "HAVING",
        "LIMIT", "OFFSET", "INSERT INTO", "VALUES", "UPDATE", "SET", "DELETE FROM",
        "INNER JOIN", "LEFT JOIN", "RIGHT JOIN", "OUTER JOIN", "JOIN", "ON",
        "UNION", "UNION ALL", "CREATE TABLE", "ALTER TABLE", "DROP TABLE"
    ]

    private static let upperKeywords: Set<String> = [
        "SELECT", "FROM", "WHERE", "AND", "OR", "NOT", "NULL", "IS", "IN", "LIKE",
        "GROUP", "BY", "ORDER", "HAVING", "LIMIT", "OFFSET", "INSERT", "INTO", "VALUES",
        "UPDATE", "SET", "DELETE", "JOIN", "INNER", "LEFT", "RIGHT", "OUTER", "ON",
        "AS", "DISTINCT", "COUNT", "SUM", "AVG", "MIN", "MAX", "UNION", "ALL", "CREATE",
        "TABLE", "ALTER", "DROP", "PRIMARY", "KEY", "FOREIGN", "REFERENCES", "DEFAULT",
        "ASC", "DESC", "BETWEEN", "EXISTS", "CASE", "WHEN", "THEN", "ELSE", "END"
    ]

    public static func format(_ sql: String) -> String {
        let tokens = tokenize(sql)
        var out = ""
        var i = 0
        var needNewline = false
        while i < tokens.count {
            let token = tokens[i]
            let upper = token.uppercased()

            // Try to match two-word keywords first (e.g. GROUP BY).
            var matchedKeyword: String?
            if i + 1 < tokens.count {
                let two = "\(upper) \(tokens[i + 1].uppercased())"
                if newlineKeywords.contains(two) { matchedKeyword = two }
            }

            if let kw = matchedKeyword {
                if !out.isEmpty { out += "\n" }
                out += kw
                i += 2
                needNewline = false
                continue
            }

            if newlineKeywords.contains(upper) {
                if !out.isEmpty { out += "\n" }
                out += upper
                needNewline = false
            } else {
                let rendered = upperKeywords.contains(upper) ? upper : token
                if token == "," {
                    out += ","
                } else if out.isEmpty || out.hasSuffix("\n") {
                    out += rendered
                } else if out.hasSuffix("(") {
                    out += rendered
                } else {
                    out += (needNewline ? "" : " ") + rendered
                }
                needNewline = false
            }
            i += 1
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func minify(_ sql: String) -> String {
        tokenize(sql).reduce(into: "") { acc, token in
            if token == "," || token == ")" {
                acc += token
            } else if acc.isEmpty || acc.hasSuffix("(") {
                acc += token
            } else {
                acc += " " + token
            }
        }.trimmingCharacters(in: .whitespaces)
    }

    private static func tokenize(_ sql: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var inString = false
        var quote: Character = "'"
        for c in sql {
            if inString {
                current.append(c)
                if c == quote { tokens.append(current); current = ""; inString = false }
                continue
            }
            if c == "'" || c == "\"" {
                if !current.isEmpty { tokens.append(current); current = "" }
                inString = true; quote = c; current.append(c)
            } else if c == "," || c == "(" || c == ")" {
                if !current.isEmpty { tokens.append(current); current = "" }
                tokens.append(String(c))
            } else if c.isWhitespace {
                if !current.isEmpty { tokens.append(current); current = "" }
            } else {
                current.append(c)
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }
}
