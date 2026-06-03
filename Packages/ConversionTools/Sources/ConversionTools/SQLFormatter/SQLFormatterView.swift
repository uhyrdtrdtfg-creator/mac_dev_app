import SwiftUI
import DevAppCore

public struct SQLFormatterView: View {
    @State private var input = ""
    @State private var output = ""

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "SQL Formatter",
            description: "Beautify or minify SQL with keyword uppercasing",
            input: $input, output: $output,
            inputLabel: "SQL", outputLabel: "Formatted",
            toolID: "sql-formatter"
        ) {
            HStack(spacing: 12) {
                Button("Format") { output = SQLFormatter.format(input) }.buttonStyle(.borderedProminent)
                Button("Minify") { output = SQLFormatter.minify(input) }.buttonStyle(.bordered)
            }
        }
        .onChange(of: input) { _, _ in output = SQLFormatter.format(input) }
    }
}

extension SQLFormatterView {
    public static let descriptor = ToolDescriptor(
        id: "sql-formatter",
        name: "SQL Formatter",
        icon: "tablecells.badge.ellipsis",
        category: .developer,
        searchKeywords: ["sql", "format", "beautify", "minify", "query", "database", "格式化"]
    )
}
