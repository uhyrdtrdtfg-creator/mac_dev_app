import SwiftUI
import DevAppCore

public struct StringEscaperView: View {
    @State private var input = ""
    @State private var output = ""
    public init() {}
    public var body: some View {
        InputOutputView(title: "String Escape / Unescape", description: "Escape and unescape backslash sequences in strings", input: $input, output: $output, inputLabel: "Unescaped", outputLabel: "Escaped")
            .onChange(of: input) { _, _ in output = StringEscaper.escape(input) }
    }
}

extension StringEscaperView {
    public static let descriptor = ToolDescriptor(id: "string-escape", name: "String Escape/Unescape", icon: "textformat", category: .conversion, searchKeywords: ["escape", "unescape", "backslash", "json", "string", "转义", "反转义"])
}
