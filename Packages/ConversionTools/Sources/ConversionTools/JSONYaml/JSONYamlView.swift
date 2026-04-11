import SwiftUI
import DevAppCore

public struct JSONYamlView: View {
    @State private var jsonText = ""
    @State private var yamlText = ""
    @State private var errorMessage: String?
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JSON ↔ YAML Converter")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Type in either panel — left converts JSON to YAML, right converts YAML to JSON")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                // JSON panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("JSON")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: jsonText)
                    }
                    TextEditor(text: $jsonText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
                }

                // Arrow
                Image(systemName: "arrow.left.arrow.right")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                    .frame(width: 20)

                // YAML panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("YAML")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: yamlText)
                    }
                    TextEditor(text: $yamlText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator, lineWidth: 0.5))
                }
            }
        }
        .padding(20)
        .onChange(of: jsonText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch YamlConverter.jsonToYaml(newValue) {
                case .success(let yaml): yamlText = yaml
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else {
                yamlText = ""
            }
            isUpdating = false
        }
        .onChange(of: yamlText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true
            errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch YamlConverter.yamlToJson(newValue) {
                case .success(let json): jsonText = json
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else {
                jsonText = ""
            }
            isUpdating = false
        }
    }
}

extension JSONYamlView {
    public static let descriptor = ToolDescriptor(
        id: "json-yaml",
        name: "JSON ↔ YAML",
        icon: "doc.plaintext",
        category: .conversion,
        searchKeywords: ["json", "yaml", "yml", "convert", "kubernetes", "k8s", "docker", "转换"]
    )
}
