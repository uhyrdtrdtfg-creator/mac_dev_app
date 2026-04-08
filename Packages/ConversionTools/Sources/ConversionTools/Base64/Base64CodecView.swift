import SwiftUI
import DevAppCore

public struct Base64CodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var urlSafe = false

    public init() {}

    public var body: some View {
        InputOutputView(title: "Base64 Encode / Decode", description: "Encode and decode Base64 strings and images", input: $input, output: $output, inputLabel: "Plain Text", outputLabel: "Base64") {
            Toggle("URL-safe", isOn: $urlSafe).toggleStyle(.checkbox)
        }
        .onChange(of: input) { _, _ in encode() }
        .onChange(of: urlSafe) { _, _ in encode() }
    }

    private func encode() {
        guard !input.isEmpty else { output = ""; return }
        output = Base64Codec.encode(input, urlSafe: urlSafe)
    }
}

extension Base64CodecView {
    public static let descriptor = ToolDescriptor(id: "base64-codec", name: "Base64 Encode/Decode", icon: "doc.text", category: .conversion, searchKeywords: ["base64", "encode", "decode", "编码", "解码"])
}
