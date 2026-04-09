import SwiftUI
import DevAppCore

public struct Base64CodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var urlSafe = false
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "Base64 Encode / Decode",
            description: "Type in either panel — left encodes, right decodes",
            input: $input,
            output: $output,
            inputLabel: "Plain Text",
            outputLabel: "Base64"
        ) {
            Toggle("URL-safe", isOn: $urlSafe).toggleStyle(.checkbox)
        }
        .onChange(of: input) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            output = newValue.isEmpty ? "" : Base64Codec.encode(newValue, urlSafe: urlSafe)
            isUpdating = false
        }
        .onChange(of: output) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            input = newValue.isEmpty ? "" : (Base64Codec.decode(newValue, urlSafe: urlSafe) ?? "")
            isUpdating = false
        }
        .onChange(of: urlSafe) { _, _ in
            guard !isUpdating else { return }
            isUpdating = true
            output = input.isEmpty ? "" : Base64Codec.encode(input, urlSafe: urlSafe)
            isUpdating = false
        }
    }
}

extension Base64CodecView {
    public static let descriptor = ToolDescriptor(
        id: "base64-codec",
        name: "Base64 Encode/Decode",
        icon: "doc.text",
        category: .conversion,
        searchKeywords: ["base64", "encode", "decode", "编码", "解码"]
    )
}
