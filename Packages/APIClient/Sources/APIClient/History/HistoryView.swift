import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HARExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] {
        if let har = UTType(filenameExtension: "har") { return [har, .json] }
        return [.json]
    }

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct HistoryView: View {
    @Query(sort: \HTTPHistoryModel.executedAt, order: .reverse)
    private var historyItems: [HTTPHistoryModel]

    @State private var harDocument: HARExportDocument?
    @State private var showHARExporter = false

    let onSelect: (HTTPHistoryModel) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if !historyItems.isEmpty {
                    Button {
                        harDocument = HARExportDocument(data: HARCodec.encode(requests: [], historyEntries: historyItems))
                        showHARExporter = true
                    } label: {
                        Image(systemName: "square.and.arrow.up").font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Export HAR")
                    Button("Clear All") { onClear() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .fileExporter(
                isPresented: $showHARExporter,
                document: harDocument,
                contentType: Self.harContentType,
                defaultFilename: "DevToolkit_History.har"
            ) { _ in harDocument = nil }

            Divider()

            if historyItems.isEmpty {
                ContentUnavailableView("No History", systemImage: "clock", description: Text("Requests will appear here after you send them"))
            } else {
                List {
                    ForEach(historyItems) { item in
                        Button { onSelect(item) } label: {
                            HStack(spacing: 8) {
                                Text(item.requestMethod)
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(methodColor(item.requestMethod))
                                    .frame(width: 52, alignment: .leading)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.requestURL)
                                        .font(.system(.caption, design: .monospaced))
                                        .lineLimit(1)
                                        .truncationMode(.middle)

                                    HStack(spacing: 8) {
                                        Text("\(item.responseStatus)")
                                            .font(.caption2)
                                            .foregroundStyle(statusColor(item.responseStatus))
                                        Text(String(format: "%.0f ms", item.duration * 1000))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                        Text(item.executedAt, style: .relative)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    private static var harContentType: UTType {
        UTType(filenameExtension: "har") ?? .json
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

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        default: .red
        }
    }
}
