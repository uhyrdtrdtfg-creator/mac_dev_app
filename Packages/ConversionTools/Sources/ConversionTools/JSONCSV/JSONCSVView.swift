import SwiftUI
import DevAppCore

public struct JSONCSVView: View {
    @State private var jsonText = ""
    @State private var csvText = ""
    @State private var errorMessage: String?
    @State private var isUpdating = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JSON ↔ CSV Converter")
                    .font(.title3).fontWeight(.bold)
                Text("Left: JSON array of objects → CSV. Right: CSV with header row → JSON")
                    .font(.caption).foregroundStyle(.tertiary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                editorPanel("JSON", text: $jsonText)
                Image(systemName: "arrow.left.arrow.right").font(.title3).foregroundStyle(.tertiary).frame(width: 20)
                editorPanel("CSV", text: $csvText)
            }
        }
        .padding(20)
        .onChange(of: jsonText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch CSVConverter.jsonToCSV(newValue) {
                case .success(let csv): csvText = csv
                case .failure(let err): errorMessage = err.localizedDescription
                }
            } else { csvText = "" }
            isUpdating = false
        }
        .onChange(of: csvText) { _, newValue in
            guard !isUpdating else { return }
            isUpdating = true; errorMessage = nil
            if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                switch CSVConverter.csvToJSON(newValue) {
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

extension JSONCSVView {
    public static let descriptor = ToolDescriptor(
        id: "json-csv",
        name: "JSON ↔ CSV",
        icon: "tablecells",
        category: .conversion,
        searchKeywords: ["json", "csv", "convert", "table", "spreadsheet", "excel", "表格"]
    )
}
