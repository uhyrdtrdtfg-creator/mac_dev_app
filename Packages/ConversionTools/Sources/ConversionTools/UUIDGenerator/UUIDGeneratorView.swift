import SwiftUI
import DevAppCore

public struct UUIDGeneratorView: View {
    @State private var batchCount = 5
    @State private var output = ""
    @State private var decodeInput = ""
    @State private var decodeResult: UUIDInfo?
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("UUID Generator").font(.title2).fontWeight(.bold)
                Text("Generate and decode UUIDs").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Stepper("Count: \(batchCount)", value: $batchCount, in: 1...100).fixedSize()
                Button("Generate") { output = UUIDGenerator.generateBatch(batchCount).joined(separator: "\n") }.buttonStyle(.borderedProminent)
                Spacer()
                CopyButton(text: output)
            }
            TextEditor(text: .constant(output)).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1)).frame(minHeight: 120)
            Divider()
            Text("Decode UUID").font(.headline)
            TextField("Paste a UUID to decode...", text: $decodeInput).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                .onChange(of: decodeInput) { _, v in decodeResult = UUIDGenerator.decode(v) }
            if let info = decodeResult {
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Version").foregroundStyle(.secondary); Spacer(); Text("\(info.version)").fontWeight(.medium) }
                    HStack { Text("Variant").foregroundStyle(.secondary); Spacer(); Text(info.variant).fontWeight(.medium) }
                    HStack { Text("Hex").foregroundStyle(.secondary); Spacer(); Text(info.hex).font(.system(.body, design: .monospaced)) }
                }.padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }.padding(20)
    }
}

extension UUIDGeneratorView {
    public static let descriptor = ToolDescriptor(id: "uuid-generator", name: "UUID Generator", icon: "number.square", category: .conversion, searchKeywords: ["uuid", "ulid", "guid", "unique", "id", "生成", "唯一"])
}
