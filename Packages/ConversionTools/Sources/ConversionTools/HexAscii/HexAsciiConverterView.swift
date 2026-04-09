import SwiftUI
import DevAppCore

public struct HexAsciiConverterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "Hex / ASCII Converter",
            description: "Type in either panel — left converts to hex, right converts to ASCII",
            input: $input, output: $output,
            inputLabel: "ASCII Text", outputLabel: "Hex"
        )
        .onChange(of: input) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            output = HexAsciiConverter.asciiToHex(newValue)
            isUpdating = false
        }
        .onChange(of: output) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            input = HexAsciiConverter.hexToAscii(newValue) ?? ""
            isUpdating = false
        }
    }
}

extension HexAsciiConverterView {
    public static let descriptor = ToolDescriptor(id: "hex-ascii", name: "Hex / ASCII Converter", icon: "01.square", category: .conversion, searchKeywords: ["hex", "ascii", "hexadecimal", "text", "convert", "十六进制"])
}
