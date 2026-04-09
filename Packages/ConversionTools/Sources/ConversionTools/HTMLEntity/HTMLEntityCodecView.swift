import SwiftUI
import DevAppCore

public struct HTMLEntityCodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "HTML Entity Encode / Decode",
            description: "Type in either panel — left encodes, right decodes",
            input: $input, output: $output,
            inputLabel: "Plain Text", outputLabel: "HTML Entities"
        )
        .onChange(of: input) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            output = HTMLEntityCodec.encode(newValue)
            isUpdating = false
        }
        .onChange(of: output) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            input = HTMLEntityCodec.decode(newValue)
            isUpdating = false
        }
    }
}

extension HTMLEntityCodecView {
    public static let descriptor = ToolDescriptor(id: "html-entity", name: "HTML Entity Encode/Decode", icon: "chevron.left.slash.chevron.right", category: .conversion, searchKeywords: ["html", "entity", "encode", "decode", "amp", "lt", "gt", "实体", "编码"])
}
