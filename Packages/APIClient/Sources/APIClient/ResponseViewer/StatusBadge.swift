import SwiftUI

struct StatusBadge: View {
    let statusCode: Int; let duration: TimeInterval; let size: Int
    var statusColor: Color { switch statusCode { case 200..<300: .green; case 300..<400: .blue; case 400..<500: .orange; default: .red } }
    var body: some View {
        HStack(spacing: 12) {
            Text("\(statusCode)").font(.system(.body, design: .monospaced)).fontWeight(.bold).foregroundStyle(statusColor).padding(.horizontal, 8).padding(.vertical, 4).background(statusColor.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 4))
            Text(String(format: "%.0fms", duration * 1000)).font(.caption).foregroundStyle(.secondary)
            Text(formattedSize).font(.caption).foregroundStyle(.secondary)
        }
    }
    private var formattedSize: String { if size < 1024 { "\(size) B" } else if size < 1048576 { String(format: "%.1f KB", Double(size) / 1024) } else { String(format: "%.1f MB", Double(size) / 1048576) } }
}
