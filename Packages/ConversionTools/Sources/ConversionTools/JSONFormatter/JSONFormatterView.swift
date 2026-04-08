import SwiftUI
import DevAppCore

public struct JSONFormatterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var indent: JSONIndent = .spaces2
    @State private var validationError: String?

    public init() {}

    public var body: some View {
        InputOutputView(title: "JSON Formatter", description: "Format, minify, and validate JSON", input: $input, output: $output, inputLabel: "Input JSON", outputLabel: "Formatted") {
            HStack(spacing: 16) {
                Picker("Indent", selection: $indent) { ForEach(JSONIndent.allCases) { i in Text(i.rawValue).tag(i) } }.pickerStyle(.segmented).frame(width: 250)
                Button("Minify") { let r = JSONFormatter.minify(input); if let m = r.output { output = m }; validationError = r.error }.buttonStyle(.bordered)
                if let validationError { Label(validationError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red) }
                else if !input.isEmpty { Label("Valid JSON", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
            }
        }
        .onChange(of: input) { _, _ in formatJSON() }
        .onChange(of: indent) { _, _ in formatJSON() }
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
