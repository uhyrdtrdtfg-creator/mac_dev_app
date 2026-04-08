import SwiftUI

struct StatusBadge: View {
    let statusCode: Int
    let duration: TimeInterval
    let size: Int

    var statusColor: Color {
        switch statusCode {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        default: .red
        }
    }

    var statusText: String {
        switch statusCode {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 301: "Moved Permanently"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 408: "Request Timeout"
        case 409: "Conflict"
        case 422: "Unprocessable Entity"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        case 502: "Bad Gateway"
        case 503: "Service Unavailable"
        case 504: "Gateway Timeout"
        default: ""
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("\(statusCode)")
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(.bold)
                if !statusText.isEmpty {
                    Text(statusText)
                        .font(.caption)
                }
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(statusColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(formattedDuration)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Text(formattedSize)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private var formattedDuration: String {
        let ms = duration * 1000
        if ms < 1000 {
            return String(format: "%.0f ms", ms)
        } else {
            return String(format: "%.2f s", duration)
        }
    }

    private var formattedSize: String {
        if size < 1024 { "\(size) B" }
        else if size < 1048576 { String(format: "%.1f KB", Double(size) / 1024) }
        else { String(format: "%.1f MB", Double(size) / 1048576) }
    }
}
