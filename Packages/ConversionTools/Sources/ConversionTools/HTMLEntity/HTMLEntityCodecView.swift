import SwiftUI
import DevAppCore

public struct HTMLEntityCodecView: View {
    @State private var input = ""; @State private var output = ""
    public init() {}
    public var body: some View {
        InputOutputView(title: "HTML Entity Encode / Decode", description: "Convert HTML special characters to entities and back", input: $input, output: $output, inputLabel: "Plain Text", outputLabel: "HTML Entities")
            .onChange(of: input) { _, _ in output = HTMLEntityCodec.encode(input) }
    }
}

extension HTMLEntityCodecView {
    public static let descriptor = ToolDescriptor(id: "html-entity", name: "HTML Entity Encode/Decode", icon: "chevron.left.slash.chevron.right", category: .conversion, searchKeywords: ["html", "entity", "encode", "decode", "amp", "lt", "gt", "实体", "编码"])
}
