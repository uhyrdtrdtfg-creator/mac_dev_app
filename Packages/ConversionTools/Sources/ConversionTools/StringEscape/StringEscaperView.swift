import SwiftUI
import DevAppCore

public struct StringEscaperView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "String Escape / Unescape",
            description: "Type in either panel — left escapes, right unescapes",
            input: $input, output: $output,
            inputLabel: "Unescaped", outputLabel: "Escaped"
        )
        .onChange(of: input) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            output = StringEscaper.escape(newValue)
            isUpdating = false
        }
        .onChange(of: output) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            input = StringEscaper.unescape(newValue)
            isUpdating = false
        }
    }
}

extension StringEscaperView {
    public static let descriptor = ToolDescriptor(id: "string-escape", name: "String Escape/Unescape", icon: "textformat", category: .conversion, searchKeywords: ["escape", "unescape", "backslash", "json", "string", "转义", "反转义"])
}
