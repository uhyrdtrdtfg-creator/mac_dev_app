import SwiftUI
import DevAppCore

public struct StringCaseConverterView: View {
    @State private var input = ""
    @State private var results: [StringCase: String] = [:]
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("String Case Converter").font(.title2).fontWeight(.bold)
                Text("Convert between camelCase, snake_case, PascalCase, and more").font(.subheadline).foregroundStyle(.secondary)
            }
            TextField("Enter text to convert...", text: $input)
                .font(.system(.title3, design: .monospaced))
                .textFieldStyle(.plain).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
            VStack(alignment: .leading, spacing: 8) {
                ForEach(StringCase.allCases) { sc in
                    HStack {
                        Text(sc.rawValue).font(.caption).foregroundStyle(.secondary).frame(width: 100, alignment: .trailing)
                        Text(results[sc] ?? "").font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        if let val = results[sc], !val.isEmpty { CopyButton(text: val) }
                    }.padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }.padding(20)
        .onChange(of: input) { _, _ in results = StringCaseConverter.convertAll(input) }
    }
}

extension StringCaseConverterView {
    public static let descriptor = ToolDescriptor(id: "string-case", name: "String Case Converter", icon: "textformat.abc", category: .conversion, searchKeywords: ["camel", "snake", "pascal", "kebab", "case", "convert", "大小写", "命名"])
}
