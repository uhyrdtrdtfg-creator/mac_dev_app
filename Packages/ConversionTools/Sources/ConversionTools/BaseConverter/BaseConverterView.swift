import SwiftUI
import DevAppCore

public struct BaseConverterView: View {
    @State private var input = ""; @State private var fromBase: NumberBase = .decimal; @State private var results: [NumberBase: String] = [:]
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Number Base Converter").font(.title2).fontWeight(.bold)
                Text("Convert between binary, octal, decimal, and hexadecimal").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Picker("From", selection: $fromBase) { ForEach(NumberBase.allCases) { b in Text(b.rawValue).tag(b) } }.pickerStyle(.menu).fixedSize()
                TextField("Enter number...", text: $input).font(.system(.title3, design: .monospaced)).textFieldStyle(.plain).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(NumberBase.allCases) { base in
                    HStack {
                        Text(base.rawValue).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
                        Text(results[base] ?? "").font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        if let val = results[base], !val.isEmpty { CopyButton(text: val) }
                    }.padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(20)
        .onChange(of: input) { _, _ in results = BaseConverter.convertAll(input, from: fromBase) }
        .onChange(of: fromBase) { _, _ in results = BaseConverter.convertAll(input, from: fromBase) }
    }
}

extension BaseConverterView {
    public static let descriptor = ToolDescriptor(id: "base-converter", name: "Number Base Converter", icon: "textformat.123", category: .conversion, searchKeywords: ["binary", "octal", "decimal", "hex", "base", "convert", "进制", "转换"])
}
