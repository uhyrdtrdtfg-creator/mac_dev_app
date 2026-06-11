import SwiftUI

struct GraphQLBodyEditor: View {
    @Binding var query: String
    @Binding var variables: String
    var url: String
    var headers: [KeyValuePair]
    var auth: AuthType?

    @State private var isFetchingSchema = false
    @State private var schemaError: String?
    @State private var schemaSummary = ""
    @State private var showSchema = false

    private var variablesError: String? { GraphQLEnvelope.variablesValidationError(variables) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Query")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                if isFetchingSchema { ProgressView().controlSize(.small) }
                Button("Fetch Schema") { fetchSchema() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isFetchingSchema || url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .help("Run the standard introspection query against the request URL")
            }
            CodeEditorView(text: $query)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                .frame(minHeight: 100)

            if let schemaError {
                Label(schemaError, systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Text("Variables (JSON)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                Spacer()
                if let variablesError {
                    Label(variablesError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                } else if !variables.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Label("Valid JSON", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            CodeEditorView(text: $variables)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                .frame(minHeight: 70)
        }
        .sheet(isPresented: $showSchema) {
            GraphQLSchemaSheet(summary: schemaSummary)
        }
    }

    private func fetchSchema() {
        schemaError = nil
        isFetchingSchema = true
        Task {
            do {
                schemaSummary = try await GraphQLIntrospection.fetchSchemaSummary(url: url, headers: headers, auth: auth)
                showSchema = true
            } catch {
                schemaError = error.localizedDescription
            }
            isFetchingSchema = false
        }
    }
}

struct GraphQLSchemaSheet: View {
    let summary: String
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var filtered: String {
        let needle = search.trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return summary }
        let blocks = summary.components(separatedBy: "\n\n")
            .filter { $0.localizedCaseInsensitiveContains(needle) }
        return blocks.isEmpty ? "No matches." : blocks.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("GraphQL Schema").font(.headline)
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(.bordered)
            }
            TextField("Search types and fields", text: $search)
                .textFieldStyle(.roundedBorder)
            ScrollView([.vertical, .horizontal]) {
                Text(filtered)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }
        .padding()
        .frame(width: 560, height: 480)
    }
}
