import SwiftUI
import DevAppCore

public struct JSONToCodeView: View {
    @Environment(\.toolHandoff) private var handoff
    @State private var input = "{\n  \"id\": 1,\n  \"name\": \"Ada\",\n  \"tags\": [\"a\", \"b\"],\n  \"profile\": { \"age\": 30, \"active\": true }\n}"
    @State private var output = ""
    @State private var language: CodeLanguage = .swift
    @State private var rootName = "Root"
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JSON → Code").font(.title2).fontWeight(.semibold)
                Text("Generate Swift structs, TypeScript interfaces, or Go structs from a JSON sample")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Language", selection: $language) {
                    ForEach(CodeLanguage.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 420)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Root name").font(.caption2).foregroundStyle(.tertiary)
                    TextField("Root", text: $rootName)
                        .textFieldStyle(.plain).frame(width: 120)
                        .padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                }
                Spacer()
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
                }
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("JSON").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("\(language.rawValue) Code").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 280)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onAppear {
            if let incoming = handoff.consume("json-to-code") { input = incoming }
            generate()
        }
        .onChange(of: input) { _, _ in generate() }
        .onChange(of: language) { _, _ in generate() }
        .onChange(of: rootName) { _, _ in generate() }
    }

    private func generate() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""; errorMessage = nil; return
        }
        let name = rootName.isEmpty ? "Root" : rootName
        switch JSONToCode.generate(json: input, language: language, rootName: name) {
        case .success(let code): output = code; errorMessage = nil
        case .failure(let err): output = ""; errorMessage = err.localizedDescription
        }
    }
}

extension JSONToCodeView {
    public static let descriptor = ToolDescriptor(
        id: "json-to-code",
        name: "JSON → Code",
        icon: "chevron.left.forwardslash.chevron.right",
        category: .generators,
        searchKeywords: ["json", "code", "swift", "typescript", "go", "struct", "interface", "model", "代码", "生成"]
    )
}
