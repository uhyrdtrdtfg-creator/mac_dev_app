import SwiftUI
import DevAppCore

public struct RandomStringGeneratorView: View {
    @State private var length = 16; @State private var batchCount = 5
    @State private var uppercase = true; @State private var lowercase = true; @State private var digits = true; @State private var special = false
    @State private var output = ""
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Random String Generator").font(.title3).fontWeight(.semibold)
                Text("Generate random strings and passwords").font(.caption).foregroundStyle(.tertiary)
            }
            HStack(spacing: 20) {
                Stepper("Length: \(length)", value: $length, in: 1...256).fixedSize()
                Stepper("Count: \(batchCount)", value: $batchCount, in: 1...100).fixedSize()
            }
            HStack(spacing: 16) {
                Toggle("A-Z", isOn: $uppercase).toggleStyle(.checkbox)
                Toggle("a-z", isOn: $lowercase).toggleStyle(.checkbox)
                Toggle("0-9", isOn: $digits).toggleStyle(.checkbox)
                Toggle("!@#$", isOn: $special).toggleStyle(.checkbox)
                Spacer()
                Button("Generate") { let opts = RandomStringOptions(length: length, uppercase: uppercase, lowercase: lowercase, digits: digits, special: special); output = RandomStringGenerator.generateBatch(batchCount, options: opts).joined(separator: "\n") }.buttonStyle(.borderedProminent)
                CopyButton(text: output)
            }
            TextEditor(text: .constant(output)).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }.padding(20)
    }
}

extension RandomStringGeneratorView {
    public static let descriptor = ToolDescriptor(id: "random-string", name: "Random String Generator", icon: "dice", category: .conversion, searchKeywords: ["random", "string", "password", "generate", "密码", "随机"])
}
