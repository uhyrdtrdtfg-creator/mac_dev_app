import SwiftUI
import DevAppCore

public struct LoremIpsumGeneratorView: View {
    @State private var count = 3
    @State private var unit: LoremUnit = .paragraphs
    @State private var output = ""
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Lorem Ipsum Generator").font(.title3).fontWeight(.semibold)
                Text("Generate placeholder text for designs and prototypes").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(spacing: 12) {
                Stepper("Count: \(count)", value: $count, in: 1...100).fixedSize()
                Picker("Unit", selection: $unit) { ForEach(LoremUnit.allCases) { u in Text(u.rawValue).tag(u) } }.pickerStyle(.segmented).fixedSize()
                Button("Generate") { output = LoremIpsumGenerator.generate(count: count, unit: unit) }.buttonStyle(.borderedProminent)
                Spacer()
                CopyButton(text: output)
            }
            TextEditor(text: .constant(output))
                .font(.system(.body))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }.padding(20)
    }
}

extension LoremIpsumGeneratorView {
    public static let descriptor = ToolDescriptor(id: "lorem-ipsum", name: "Lorem Ipsum Generator", icon: "text.justify.left", category: .conversion, searchKeywords: ["lorem", "ipsum", "placeholder", "text", "generate", "占位", "文本"])
}
