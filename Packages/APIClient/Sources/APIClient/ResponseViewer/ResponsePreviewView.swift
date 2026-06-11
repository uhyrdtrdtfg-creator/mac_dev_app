import SwiftUI
import AppKit
import WebKit
import PDFKit

// MARK: - Preview kind mapping (pure)

enum ResponsePreviewKind: Equatable, Sendable {
    case image
    case svg
    case html
    case pdf
    case audioVideo
    case text
    case binary
}

/// Maps a Content-Type header (plus the first bytes of the body for sniffing) to a preview kind.
/// `bodyPrefix` is consulted when the content type is missing or generic.
func previewKind(contentType: String?, bodyPrefix: Data) -> ResponsePreviewKind {
    let normalized: String = {
        guard let raw = contentType?.split(separator: ";", maxSplits: 1).first else { return "" }
        return raw.trimmingCharacters(in: .whitespaces).lowercased()
    }()

    switch normalized {
    case "", "application/octet-stream", "binary/octet-stream":
        return sniffPreviewKind(bodyPrefix)
    case "image/svg+xml":
        return .svg
    case "text/html", "application/xhtml+xml":
        return .html
    case "application/pdf":
        return .pdf
    case "application/json", "application/javascript", "application/xml", "application/x-www-form-urlencoded":
        return .text
    default:
        if normalized.hasPrefix("image/") { return .image }
        if normalized.hasPrefix("audio/") || normalized.hasPrefix("video/") { return .audioVideo }
        if normalized.hasPrefix("text/") { return .text }
        if normalized.hasSuffix("+json") || normalized.hasSuffix("+xml") { return .text }
        return sniffPreviewKind(bodyPrefix)
    }
}

/// Magic-byte sniffing fallback for generic/missing content types.
func sniffPreviewKind(_ prefix: Data) -> ResponsePreviewKind {
    let bytes = [UInt8](prefix.prefix(512))
    func starts(with magic: [UInt8], at offset: Int = 0) -> Bool {
        guard bytes.count >= offset + magic.count else { return false }
        return Array(bytes[offset..<offset + magic.count]) == magic
    }
    func startsASCII(_ s: String, at offset: Int = 0) -> Bool { starts(with: Array(s.utf8), at: offset) }

    if starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return .image } // PNG
    if starts(with: [0xFF, 0xD8, 0xFF]) { return .image } // JPEG
    if startsASCII("GIF87a") || startsASCII("GIF89a") { return .image }
    if startsASCII("RIFF"), startsASCII("WEBP", at: 8) { return .image }
    if startsASCII("%PDF") { return .pdf }

    // Text vs binary: NUL byte or non-UTF-8 prefix means binary.
    guard !bytes.isEmpty else { return .text }
    if bytes.contains(0) { return .binary }
    var utf8Bytes = bytes
    var decoded: String?
    for _ in 0..<4 { // a multi-byte character may be cut at the prefix boundary
        if let s = String(bytes: utf8Bytes, encoding: .utf8) { decoded = s; break }
        if utf8Bytes.isEmpty { break }
        utf8Bytes.removeLast()
    }
    guard let textPrefix = decoded else { return .binary }

    let trimmed = textPrefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    if trimmed.hasPrefix("<!doctype html") || trimmed.hasPrefix("<html") { return .html }
    if trimmed.hasPrefix("<svg") || (trimmed.hasPrefix("<?xml") && trimmed.contains("<svg")) { return .svg }
    return .text
}

// MARK: - Hex dump (pure)

enum HexDump {
    /// Only the first `maxBytes` are formatted; callers show a truncation banner beyond that.
    static let maxBytes = 64 * 1024
    static let bytesPerRow = 16

    static func format(_ data: Data, maxBytes: Int = HexDump.maxBytes) -> (text: String, truncated: Bool) {
        let bytes = [UInt8](data.prefix(maxBytes))
        var lines: [String] = []
        lines.reserveCapacity((bytes.count + bytesPerRow - 1) / bytesPerRow)
        for rowStart in stride(from: 0, to: bytes.count, by: bytesPerRow) {
            let row = bytes[rowStart..<min(rowStart + bytesPerRow, bytes.count)]
            var hex = ""
            var ascii = ""
            for (offset, byte) in row.enumerated() {
                hex += String(format: "%02X ", byte)
                if offset == 7 { hex += " " }
                ascii.append(byte >= 0x20 && byte < 0x7F ? Character(UnicodeScalar(byte)) : ".")
            }
            let hexWidth = bytesPerRow * 3 + 1 // 16 byte triplets + mid-row gap
            let paddedHex = hex.padding(toLength: hexWidth, withPad: " ", startingAt: 0)
            lines.append(String(format: "%08X  ", rowStart) + paddedHex + " |" + ascii + "|")
        }
        return (lines.joined(separator: "\n"), data.count > maxBytes)
    }
}

// MARK: - Preview view

struct ResponsePreviewView: View {
    let response: HTTPResponse

    private var contentType: String? {
        response.headers.first { $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame }?.value
    }

    var body: some View {
        switch previewKind(contentType: contentType, bodyPrefix: response.body.prefix(512)) {
        case .image:
            imagePreview(failureNote: "Unable to decode image data.")
        case .svg:
            imagePreview(failureNote: "SVG preview failed — use Save… to view it in an external app.")
        case .html:
            StaticHTMLView(html: String(decoding: response.body, as: UTF8.self))
        case .pdf:
            PDFPreviewView(data: response.body)
        case .audioVideo:
            ContentUnavailableView {
                Label("Audio / Video Response", systemImage: "play.rectangle")
            } description: {
                Text("Inline playback is not supported. Use Save… to write the response to a file and preview it externally.")
            }
        case .text:
            CodeEditorView(text: .constant(String(decoding: response.body, as: UTF8.self)), isEditable: false)
        case .binary:
            hexDumpView
        }
    }

    @ViewBuilder
    private func imagePreview(failureNote: String) -> some View {
        if let image = NSImage(data: response.body) {
            ScrollView([.horizontal, .vertical]) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: image.size.width, maxHeight: image.size.height)
                    .padding(12)
            }
        } else {
            ContentUnavailableView {
                Label("Preview Unavailable", systemImage: "photo")
            } description: {
                Text(failureNote)
            }
        }
    }

    private var hexDumpView: some View {
        let dump = HexDump.format(response.body)
        return VStack(spacing: 0) {
            if dump.truncated {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text("Showing first \(HexDump.maxBytes / 1024) KB of \(response.body.count) bytes.")
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.yellow.opacity(0.12))
            }
            ScrollView([.horizontal, .vertical]) {
                Text(dump.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
    }
}

// MARK: - WebKit / PDFKit wrappers

private struct StaticHTMLView: NSViewRepresentable {
    let html: String

    final class Coordinator {
        var lastHTML: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        return WKWebView(frame: .zero, configuration: config)
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.lastHTML != html else { return }
        context.coordinator.lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }
}

private struct PDFPreviewView: NSViewRepresentable {
    let data: Data

    final class Coordinator {
        var lastData: Data?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        return view
    }

    func updateNSView(_ view: PDFView, context: Context) {
        guard context.coordinator.lastData != data else { return }
        context.coordinator.lastData = data
        view.document = PDFDocument(data: data)
    }
}
