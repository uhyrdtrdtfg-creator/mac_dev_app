import SwiftUI
import DevAppCore

public struct XMLFormatterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var indent: XMLIndent = .spaces2
    @State private var validationError: String?
    @State private var xpath = ""
    @State private var queryResult = ""
    @State private var queryCount: Int?
    @State private var queryError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InputOutputView(title: "XML Formatter", description: "Format, minify, validate, and query XML with XPath", input: $input, output: $output, inputLabel: "Input XML", outputLabel: "Formatted", toolID: "xml-formatter") {
                HStack(spacing: 16) {
                    Picker("Indent", selection: $indent) { ForEach(XMLIndent.allCases) { i in Text(i.rawValue).tag(i) } }.pickerStyle(.segmented).frame(width: 250)
                    Button("Minify") { let r = XMLFormatter.minify(input); if let m = r.output { output = m }; validationError = r.error }.buttonStyle(.bordered)
                    if let validationError { Label(validationError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red).lineLimit(1) }
                    else if !input.isEmpty { Label("Valid XML", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
                }
            }

            // XPath query
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("XPath 1.0, e.g. //book/@id  or  //title/text()  — namespaced elements need prefixes (default namespace: use *[local-name()='x'])", text: $xpath)
                        .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    if let queryError { Label(queryError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red).lineLimit(1) }
                }
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

                if let queryCount {
                    HStack {
                        Text(queryCount == 1 ? "1 match" : "\(queryCount) matches").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: queryResult)
                    }
                    if !queryResult.isEmpty {
                        ScrollView {
                            Text(queryResult).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: input) { _, _ in formatXML(); runQuery() }
        .onChange(of: indent) { _, _ in formatXML() }
        .onChange(of: xpath) { _, _ in runQuery() }
    }

    private func formatXML() {
        guard !input.isEmpty else { output = ""; validationError = nil; return }
        let result = XMLFormatter.format(input, indent: indent)
        output = result.output ?? ""
        validationError = result.error
    }

    private func runQuery() {
        guard !xpath.trimmingCharacters(in: .whitespaces).isEmpty, !input.isEmpty else {
            queryResult = ""; queryCount = nil; queryError = nil; return
        }
        let result = XPathQuery.query(input, xpath: xpath)
        queryResult = result.output ?? ""
        queryCount = result.error == nil ? result.matchCount : nil
        queryError = result.error
    }
}

extension XMLFormatterView {
    public static let descriptor = ToolDescriptor(id: "xml-formatter", name: "XML Formatter", icon: "tag", category: .conversion, searchKeywords: ["xml", "format", "beautify", "minify", "validate", "xpath", "query", "格式化", "校验", "查询"])
}
