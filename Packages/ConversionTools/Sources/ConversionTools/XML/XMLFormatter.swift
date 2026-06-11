import Foundation

public enum XMLIndent: String, CaseIterable, Identifiable, Sendable {
    case spaces2 = "2 Spaces"
    case spaces4 = "4 Spaces"
    case tab = "Tab"
    public var id: String { rawValue }
}

public struct XMLFormatResult: Sendable {
    public let output: String?
    public let error: String?
}

public struct XMLValidationResult: Sendable {
    public let isValid: Bool
    public let error: String?
}

public enum XMLFormatter {
    static let parseOptions: XMLNode.Options = [.nodePreserveCDATA, .nodePreserveAttributeOrder, .nodePreserveNamespaceOrder, .nodePreserveEntities, .nodePreservePrefixes]

    public static func format(_ input: String, indent: XMLIndent = .spaces2) -> XMLFormatResult {
        let (doc, error) = parse(input)
        guard let doc else { return XMLFormatResult(output: nil, error: error) }
        var result = doc.xmlString(options: [.nodePrettyPrint, .nodePreserveCDATA])
        if !hasDeclaration(input) { result = stripDeclaration(result) }
        switch indent {
        case .spaces4: break
        case .spaces2: result = reindent(result, unit: "  ")
        case .tab: result = reindent(result, unit: "\t")
        }
        return XMLFormatResult(output: result, error: nil)
    }

    public static func minify(_ input: String) -> XMLFormatResult {
        let (doc, error) = parse(input)
        guard let doc else { return XMLFormatResult(output: nil, error: error) }
        var result = doc.xmlString(options: [.nodePreserveCDATA])
        if !hasDeclaration(input) { result = stripDeclaration(result) }
        return XMLFormatResult(output: result, error: nil)
    }

    public static func validate(_ input: String) -> XMLValidationResult {
        let (doc, error) = parse(input)
        return XMLValidationResult(isValid: doc != nil, error: error)
    }

    static func parse(_ input: String) -> (doc: XMLDocument?, error: String?) {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, "Empty input")
        }
        do {
            let doc = try XMLDocument(xmlString: input, options: parseOptions)
            // Don't synthesize standalone="yes" the input never declared.
            if !declarationPrefix(input).contains("standalone") { doc.isStandalone = false }
            return (doc, nil)
        } catch {
            let message = (error as NSError).localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            return (nil, message.isEmpty ? "Invalid XML" : message)
        }
    }

    private static func hasDeclaration(_ input: String) -> Bool {
        input.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<?xml")
    }

    private static func declarationPrefix(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("<?xml"), let end = trimmed.range(of: "?>") else { return "" }
        return String(trimmed[..<end.lowerBound])
    }

    private static func stripDeclaration(_ output: String) -> String {
        guard output.hasPrefix("<?xml"), let end = output.range(of: "?>") else { return output }
        var rest = String(output[end.upperBound...])
        while rest.first == "\n" || rest.first == " " { rest.removeFirst() }
        return rest
    }

    /// XMLDocument pretty print always indents with 4 spaces per level; remap to the requested unit.
    private static func reindent(_ pretty: String, unit: String) -> String {
        pretty.components(separatedBy: "\n").map { line in
            var level = 0
            var idx = line.startIndex
            while line[idx...].hasPrefix("    ") { level += 1; idx = line.index(idx, offsetBy: 4) }
            return level == 0 ? line : String(repeating: unit, count: level) + line[idx...]
        }.joined(separator: "\n")
    }
}
