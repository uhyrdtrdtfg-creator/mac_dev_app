import Foundation

public enum MarkdownToHTML {
    public static func convert(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: "\n")
        var html: [String] = []
        var i = 0

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .init(charactersIn: " "))

            // Empty line
            if trimmed.isEmpty {
                html.append("")
                i += 1
                continue
            }

            // Headings
            if let heading = parseHeading(trimmed) {
                html.append(heading)
                i += 1
                continue
            }

            // Horizontal rule
            if isHorizontalRule(trimmed) {
                html.append("<hr>")
                i += 1
                continue
            }

            // Code block (fenced)
            if trimmed.hasPrefix("```") {
                let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                var codeLines: [String] = []
                i += 1
                while i < lines.count && !lines[i].trimmingCharacters(in: .init(charactersIn: " ")).hasPrefix("```") {
                    codeLines.append(escapeHTML(lines[i]))
                    i += 1
                }
                let langAttr = lang.isEmpty ? "" : " class=\"language-\(lang)\""
                html.append("<pre><code\(langAttr)>\(codeLines.joined(separator: "\n"))</code></pre>")
                i += 1
                continue
            }

            // Blockquote
            if trimmed.hasPrefix("> ") || trimmed == ">" {
                var quoteLines: [String] = []
                while i < lines.count {
                    let ql = lines[i].trimmingCharacters(in: .init(charactersIn: " "))
                    if ql.hasPrefix("> ") { quoteLines.append(String(ql.dropFirst(2))) }
                    else if ql == ">" { quoteLines.append("") }
                    else { break }
                    i += 1
                }
                html.append("<blockquote>\(convertInline(quoteLines.joined(separator: "<br>")))</blockquote>")
                continue
            }

            // Table
            if trimmed.contains("|") && i + 1 < lines.count && lines[i + 1].trimmingCharacters(in: .whitespaces).contains("---") {
                var tableHTML = "<table>"
                // Header
                let headers = parseTableRow(trimmed)
                tableHTML += "<thead><tr>" + headers.map { "<th>\(convertInline($0))</th>" }.joined() + "</tr></thead>"
                i += 2 // skip header + separator
                tableHTML += "<tbody>"
                while i < lines.count && lines[i].contains("|") {
                    let cells = parseTableRow(lines[i])
                    tableHTML += "<tr>" + cells.map { "<td>\(convertInline($0))</td>" }.joined() + "</tr>"
                    i += 1
                }
                tableHTML += "</tbody></table>"
                html.append(tableHTML)
                continue
            }

            // Unordered list
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                var listItems: [String] = []
                while i < lines.count {
                    let ll = lines[i].trimmingCharacters(in: .init(charactersIn: " "))
                    if ll.hasPrefix("- ") || ll.hasPrefix("* ") || ll.hasPrefix("+ ") {
                        var content = String(ll.dropFirst(2))
                        // Checkbox
                        if content.hasPrefix("[ ] ") {
                            content = "<input type=\"checkbox\" disabled>" + String(content.dropFirst(4))
                        } else if content.hasPrefix("[x] ") || content.hasPrefix("[X] ") {
                            content = "<input type=\"checkbox\" checked disabled>" + String(content.dropFirst(4))
                        }
                        listItems.append(content)
                    } else if ll.isEmpty { break }
                    else { break }
                    i += 1
                }
                html.append("<ul>" + listItems.map { "<li>\(convertInline($0))</li>" }.joined() + "</ul>")
                continue
            }

            // Ordered list
            if let _ = trimmed.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                var listItems: [String] = []
                while i < lines.count {
                    let ll = lines[i].trimmingCharacters(in: .init(charactersIn: " "))
                    if let range = ll.range(of: #"^\d+\.\s"#, options: .regularExpression) {
                        listItems.append(String(ll[range.upperBound...]))
                    } else if ll.isEmpty { break }
                    else { break }
                    i += 1
                }
                html.append("<ol>" + listItems.map { "<li>\(convertInline($0))</li>" }.joined() + "</ol>")
                continue
            }

            // Paragraph
            var paraLines: [String] = []
            while i < lines.count {
                let pl = lines[i]
                let pt = pl.trimmingCharacters(in: .init(charactersIn: " "))
                if pt.isEmpty || pt.hasPrefix("#") || pt.hasPrefix("```") || pt.hasPrefix("> ") || pt.hasPrefix("- ") || pt.hasPrefix("* ") || isHorizontalRule(pt) { break }
                if let _ = pt.range(of: #"^\d+\.\s"#, options: .regularExpression) { break }
                paraLines.append(pt)
                i += 1
            }
            if !paraLines.isEmpty {
                html.append("<p>\(convertInline(paraLines.joined(separator: "\n")))</p>")
            }
        }

        return html.joined(separator: "\n")
    }

    // MARK: - Inline formatting

    private static func convertInline(_ text: String) -> String {
        var result = escapeHTML(text)

        // Images: ![alt](url)
        result = result.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(([^)]+)\)"#,
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        // Links: [text](url)
        result = result.replacingOccurrences(
            of: #"\[([^\]]+)\]\(([^)]+)\)"#,
            with: "<a href=\"$2\">$1</a>",
            options: .regularExpression
        )

        // Bold + Italic: ***text*** or ___text___
        result = result.replacingOccurrences(
            of: #"\*\*\*(.+?)\*\*\*"#, with: "<strong><em>$1</em></strong>", options: .regularExpression
        )

        // Bold: **text** or __text__
        result = result.replacingOccurrences(
            of: #"\*\*(.+?)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"__(.+?)__"#, with: "<strong>$1</strong>", options: .regularExpression
        )

        // Italic: *text* or _text_
        result = result.replacingOccurrences(
            of: #"\*(.+?)\*"#, with: "<em>$1</em>", options: .regularExpression
        )
        result = result.replacingOccurrences(
            of: #"(?<!\w)_(.+?)_(?!\w)"#, with: "<em>$1</em>", options: .regularExpression
        )

        // Strikethrough: ~~text~~
        result = result.replacingOccurrences(
            of: #"~~(.+?)~~"#, with: "<del>$1</del>", options: .regularExpression
        )

        // Inline code: `text`
        result = result.replacingOccurrences(
            of: #"`([^`]+)`"#, with: "<code>$1</code>", options: .regularExpression
        )

        // Line breaks
        result = result.replacingOccurrences(of: "  \n", with: "<br>")
        result = result.replacingOccurrences(of: "\n", with: "<br>")

        return result
    }

    // MARK: - Helpers

    private static func parseHeading(_ line: String) -> String? {
        var level = 0
        for c in line { if c == "#" { level += 1 } else { break } }
        guard level >= 1 && level <= 6 && line.count > level && line[line.index(line.startIndex, offsetBy: level)] == " " else { return nil }
        let content = String(line.dropFirst(level + 1))
        return "<h\(level)>\(convertInline(content))</h\(level)>"
    }

    private static func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.replacingOccurrences(of: " ", with: "")
        return (trimmed.allSatisfy({ $0 == "-" }) || trimmed.allSatisfy({ $0 == "*" }) || trimmed.allSatisfy({ $0 == "_" })) && trimmed.count >= 3
    }

    private static func parseTableRow(_ line: String) -> [String] {
        line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
