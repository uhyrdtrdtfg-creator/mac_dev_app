import SwiftUI
import DevAppCore

public struct JSONFormatterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var indent: JSONIndent = .spaces2
    @State private var validationError: String?
    @State private var jsonPath = ""
    @State private var queryResult = ""
    @State private var queryError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InputOutputView(title: "JSON Formatter", description: "Format, minify, validate, and query JSON", input: $input, output: $output, inputLabel: "Input JSON", outputLabel: "Formatted", toolID: "json-formatter") {
                HStack(spacing: 16) {
                    Picker("Indent", selection: $indent) { ForEach(JSONIndent.allCases) { i in Text(i.rawValue).tag(i) } }.pickerStyle(.segmented).frame(width: 250)
                    Button("Minify") { let r = JSONFormatter.minify(input); if let m = r.output { output = m }; validationError = r.error }.buttonStyle(.bordered)
                    if let validationError { Label(validationError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red) }
                    else if !input.isEmpty { Label("Valid JSON", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
                }
            }

            // JSONPath query
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("JSONPath, e.g. $.items[0].name  or  $.users[*].id", text: $jsonPath)
                        .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    if let queryError { Label(queryError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red) }
                }
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

                if !queryResult.isEmpty {
                    HStack {
                        Text("Result").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: queryResult)
                    }
                    ScrollView {
                        Text(queryResult).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 200)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(.horizontal, 20)
        }
        .onChange(of: input) { _, _ in formatJSON(); runQuery() }
        .onChange(of: indent) { _, _ in formatJSON() }
        .onChange(of: jsonPath) { _, _ in runQuery() }
    }

    private func runQuery() {
        guard !jsonPath.trimmingCharacters(in: .whitespaces).isEmpty, !input.isEmpty else {
            queryResult = ""; queryError = nil; return
        }
        let result = JSONPathQuery.query(input, path: jsonPath)
        queryResult = result.output ?? ""
        queryError = result.error
    }

    private func formatJSON() {
        guard !input.isEmpty else { output = ""; validationError = nil; return }
        let result = JSONFormatter.format(input, indent: indent)
        output = result.output ?? ""
        validationError = result.error
    }
}

extension JSONFormatterView {
    public static let descriptor = ToolDescriptor(id: "json-formatter", name: "JSON Formatter", icon: "curlybraces", category: .conversion, searchKeywords: ["json", "format", "beautify", "minify", "validate", "格式化", "校验"])
}
