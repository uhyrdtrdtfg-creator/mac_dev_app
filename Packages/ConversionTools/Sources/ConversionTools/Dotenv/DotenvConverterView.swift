import SwiftUI
import DevAppCore

public struct DotenvConverterView: View {
    @State private var envText = ""
    @State private var jsonText = ""
    @State private var errorMessage: String?
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(".env / .ini ↔ JSON").font(.title3).fontWeight(.bold)
                Text("Left: KEY=VALUE or [section] config → JSON. Right: JSON → config")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                editorPanel(".env / .ini", text: $envText)
                Image(systemName: "arrow.left.arrow.right").font(.title3).foregroundStyle(.tertiary).frame(width: 20)
                editorPanel("JSON", text: $jsonText)
            }
        }
        .padding(20)
        .onChange(of: envText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch DotenvConverter.toJSON(newValue) {
                case .success(let json): jsonText = json
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else { jsonText = "" }
            isUpdating = false
        }
        .onChange(of: jsonText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch DotenvConverter.fromJSON(newValue) {
                case .success(let env): envText = env
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else { envText = "" }
            isUpdating = false
        }
    }

    private func editorPanel(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                CopyButton(text: text.wrappedValue)
            }
            TextEditor(text: text)
                .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
        }
    }
}

extension DotenvConverterView {
    public static let descriptor = ToolDescriptor(
        id: "dotenv-json",
        name: ".env ↔ JSON",
        icon: "doc.text.below.ecg",
        category: .developer,
        searchKeywords: ["env", "dotenv", "ini", "properties", "config", "json", "环境变量", "配置"]
    )
}
