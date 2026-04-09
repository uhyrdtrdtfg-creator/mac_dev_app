import SwiftUI
import SwiftData
import AppKit

struct SavedRequestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedRequestModel.updatedAt, order: .reverse)
    private var savedRequests: [SavedRequestModel]

    @State private var selectedTag: String?
    @State private var searchText = ""
    @State private var showImportSheet = false
    @State private var importText = ""
    @State private var importFormat: ImportFormat = .postmanCollection
    @State private var showExportSheet = false
    @State private var exportFormat: ExportFormat = .postmanCollection

    let onSelect: (SavedRequestModel) -> Void

    enum ImportFormat: String, CaseIterable, Identifiable {
        case postmanCollection = "Postman Collection"
        case curl = "cURL Commands"
        var id: String { rawValue }
    }

    enum ExportFormat: String, CaseIterable, Identifiable {
        case postmanCollection = "Postman Collection"
        case devToolkit = "DevToolkit JSON"
        var id: String { rawValue }
    }

    var allTags: [String] {
        let tags = savedRequests.flatMap { $0.tagList }
        return Array(Set(tags)).sorted()
    }

    var filteredRequests: [SavedRequestModel] {
        var result = savedRequests
        if let tag = selectedTag {
            result = result.filter { $0.tagList.contains(tag) }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(query) ||
                $0.url.lowercased().contains(query) ||
                $0.method.lowercased().contains(query)
            }
        }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Saved APIs")
                    .font(.headline)
                Spacer()

                Button {
                    showImportSheet.toggle()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Import")
                .popover(isPresented: $showImportSheet) {
                    importView
                }

                Button {
                    exportAll()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
                .help("Export All")
                .popover(isPresented: $showExportSheet) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Export Format").font(.headline)
                        Picker("Format", selection: $exportFormat) {
                            ForEach(ExportFormat.allCases) { fmt in
                                Text(fmt.rawValue).tag(fmt)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        Text(exportFormat == .postmanCollection
                             ? "Exports as Postman Collection v2.1 (compatible with Postman import). Includes pre-request and test scripts."
                             : "Exports as DevToolkit JSON. Includes all scripts (pre/post/rewrite).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Spacer()
                            Button("Cancel") { showExportSheet = false }
                                .buttonStyle(.bordered)
                            Button("Export") { performExport(); showExportSheet = false }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .frame(width: 380)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Search
            TextField("Search saved APIs...", text: $searchText)
                .textFieldStyle(.plain)
                .padding(6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)

            // Tags filter
            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        tagButton(nil, label: "All")
                        ForEach(allTags, id: \.self) { tag in
                            tagButton(tag, label: tag)
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 6)
            }

            Divider()

            // Request list
            if filteredRequests.isEmpty {
                ContentUnavailableView("No Saved APIs", systemImage: "bookmark", description: Text("Save a request to see it here"))
            } else {
                List {
                    ForEach(filteredRequests) { req in
                        Button { onSelect(req) } label: {
                            HStack(spacing: 8) {
                                Text(req.method)
                                    .font(.system(.caption2, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(methodColor(req.method))
                                    .frame(width: 48, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(req.name)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    Text(req.url)
                                        .font(.system(.caption2, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    if !req.tagList.isEmpty {
                                        HStack(spacing: 4) {
                                            ForEach(req.tagList, id: \.self) { tag in
                                                Text(tag)
                                                    .font(.caption2)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 1)
                                                    .background(.blue.opacity(0.1))
                                                    .foregroundStyle(.blue)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("Delete", role: .destructive) {
                                modelContext.delete(req)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private func tagButton(_ tag: String?, label: String) -> some View {
        Button {
            selectedTag = tag
        } label: {
            Text(label)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(selectedTag == tag ? Color.accentColor : Color.secondary.opacity(0.15))
                .foregroundStyle(selectedTag == tag ? .white : .primary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Import View

    private var importView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Import APIs").font(.headline)

            Picker("Format", selection: $importFormat) {
                ForEach(ImportFormat.allCases) { fmt in
                    Text(fmt.rawValue).tag(fmt)
                }
            }
            .pickerStyle(.segmented)

            Text(importFormat == .postmanCollection
                 ? "Paste Postman Collection JSON (v2.1)"
                 : "Paste one or more cURL commands (one per line)")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $importText)
                .font(.system(.caption, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(6)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Spacer()
                Button("Cancel") { showImportSheet = false; importText = "" }
                    .buttonStyle(.bordered)
                Button("Import") {
                    performImport()
                    showImportSheet = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 500, height: 350)
    }

    // MARK: - Import Logic

    private func performImport() {
        switch importFormat {
        case .postmanCollection:
            let requests = ImportExportService.importPostmanCollection(importText)
            for req in requests {
                modelContext.insert(req)
            }
        case .curl:
            let requests = ImportExportService.importCurlCommands(importText)
            for req in requests {
                modelContext.insert(req)
            }
        }
        importText = ""
    }

    // MARK: - Export

    private func exportAll() {
        showExportSheet = true
    }

    private func performExport() {
        let json: String
        let filename: String
        switch exportFormat {
        case .postmanCollection:
            json = ImportExportService.exportAsPostmanCollection(savedRequests)
            filename = "DevToolkit_Collection.postman_collection.json"
        case .devToolkit:
            json = ImportExportService.exportAsJSON(savedRequests)
            filename = "DevToolkit_APIs.json"
        }

        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.allowedContentTypes = [.json]
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? json.write(to: url, atomically: true, encoding: .utf8)
            }
        }
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": .green
        case "POST": .orange
        case "PUT": .blue
        case "PATCH": .purple
        case "DELETE": .red
        default: .gray
        }
    }
}
