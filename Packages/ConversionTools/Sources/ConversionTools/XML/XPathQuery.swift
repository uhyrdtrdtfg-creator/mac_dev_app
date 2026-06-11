import Foundation

public struct XPathQueryResult: Sendable {
    public let output: String?
    public let matchCount: Int
    public let error: String?
}

/// XPath 1.0 evaluation via XMLNode.nodes(forXPath:). Namespaced elements
/// generally require prefixes (e.g. //bk:book); use *[local-name()='x'] as a fallback.
public enum XPathQuery {
    public static func query(_ xml: String, xpath: String) -> XPathQueryResult {
        let expression = xpath.trimmingCharacters(in: .whitespaces)
        guard !expression.isEmpty else { return XPathQueryResult(output: nil, matchCount: 0, error: nil) }
        let (doc, parseError) = XMLFormatter.parse(xml)
        guard let doc else { return XPathQueryResult(output: nil, matchCount: 0, error: parseError) }
        do {
            let nodes = try doc.nodes(forXPath: expression)
            let rendered = nodes.map(render).joined(separator: "\n")
            return XPathQueryResult(output: rendered, matchCount: nodes.count, error: nil)
        } catch {
            let ns = error as NSError
            let message = (ns.userInfo["ErrorMessage"] as? String) ?? ns.localizedDescription
            return XPathQueryResult(output: nil, matchCount: 0, error: "Invalid XPath: \(message.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
    }

    private static func render(_ node: XMLNode) -> String {
        switch node.kind {
        case .element, .document: return node.xmlString(options: [.nodePreserveCDATA])
        case .attribute, .text: return node.stringValue ?? ""
        default: return node.xmlString
        }
    }
}
