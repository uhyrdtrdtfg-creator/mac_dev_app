import SwiftUI
import DevAppCore

public struct JSONTOMLView: View {
    @State private var jsonText = ""
    @State private var tomlText = ""
    @State private var errorMessage: String?
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JSON ↔ TOML Converter")
                    .font(.title3).fontWeight(.bold)
                Text("Type in either panel. Supports tables, nested tables, scalar arrays and arrays of tables")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                editorPanel("JSON", text: $jsonText)
                Image(systemName: "arrow.left.arrow.right").font(.title3).foregroundStyle(.tertiary).frame(width: 20)
                editorPanel("TOML", text: $tomlText)
            }
        }
        .padding(20)
        .onChange(of: jsonText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch TOMLConverter.jsonToTOML(newValue) {
                case .success(let toml): tomlText = toml
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else { tomlText = "" }
            isUpdating = false
        }
        .onChange(of: tomlText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch TOMLConverter.tomlToJSON(newValue) {
                case .success(let json): jsonText = json
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else { jsonText = "" }
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
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
        }
    }
}

extension JSONTOMLView {
    public static let descriptor = ToolDescriptor(
        id: "json-toml",
        name: "JSON ↔ TOML",
        icon: "doc.badge.gearshape",
        category: .conversion,
        searchKeywords: ["json", "toml", "convert", "config", "cargo", "配置", "转换"]
    )
}
