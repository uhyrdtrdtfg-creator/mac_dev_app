import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \HTTPHistoryModel.executedAt, order: .reverse)
    private var historyItems: [HTTPHistoryModel]

    let onSelect: (HTTPHistoryModel) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("History")
                    .font(.headline)
                Spacer()
                if !historyItems.isEmpty {
                    Button("Clear All") { onClear() }
                        .font(.caption)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

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
