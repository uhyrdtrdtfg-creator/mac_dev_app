import SwiftUI
import DevAppCore

public struct HexAsciiConverterView: View {
    @State private var input = ""
    @State private var output = ""
    public init() {}
    public var body: some View {
        InputOutputView(title: "Hex / ASCII Converter", description: "Convert between hexadecimal and ASCII text", input: $input, output: $output, inputLabel: "ASCII Text", outputLabel: "Hex")
            .onChange(of: input) { _, _ in output = HexAsciiConverter.asciiToHex(input) }
    }
}

extension HexAsciiConverterView {
    public static let descriptor = ToolDescriptor(id: "hex-ascii", name: "Hex / ASCII Converter", icon: "01.square", category: .conversion, searchKeywords: ["hex", "ascii", "hexadecimal", "text", "convert", "十六进制"])
}
