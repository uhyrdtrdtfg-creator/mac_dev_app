import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum ResponseFilename {
    static let maxFilenameBytes = 255

    /// Infers a filename for saving a response body:
    /// Content-Disposition filename*= (RFC 5987), then filename=, then the last URL
    /// path component, then "response" + extension from the Content-Type.
    static func infer(contentDisposition: String?, contentType: String?, requestURL: String?) -> String {
        if let disposition = contentDisposition {
            if let name = rfc5987Filename(in: disposition), !sanitize(name).isEmpty {
                return sanitize(name)
            }
            if let name = plainFilename(in: disposition), !sanitize(name).isEmpty {
                return sanitize(name)
            }
        }
        if let urlString = requestURL, let url = URL(string: urlString) {
            let last = url.lastPathComponent
            if !last.isEmpty, last != "/", last != ".." {
                let sanitized = sanitize(last)
                if !sanitized.isEmpty { return sanitized }
            }
        }
        if let ext = fileExtension(forContentType: contentType) {
            return sanitize("response." + ext)
        }
        return "response"
    }

    /// Case-insensitive header lookup.
    static func headerValue(_ name: String, in headers: [String: String]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    /// UTType for the fileExporter, derived from the Content-Type header.
    static func exportType(forContentType contentType: String?) -> UTType {
        guard let mime = primaryMimeType(contentType) else { return .data }
        return UTType(mimeType: mime) ?? .data
    }

    static func fileExtension(forContentType contentType: String?) -> String? {
        guard let mime = primaryMimeType(contentType) else { return nil }
        return UTType(mimeType: mime)?.preferredFilenameExtension
    }

    private static func primaryMimeType(_ contentType: String?) -> String? {
        guard let raw = contentType?.split(separator: ";", maxSplits: 1).first else { return nil }
        let mime = raw.trimmingCharacters(in: .whitespaces).lowercased()
        return mime.isEmpty ? nil : mime
    }

    // MARK: - Content-Disposition parsing

    /// filename*=UTF-8''percent%20encoded (RFC 5987).
    static func rfc5987Filename(in disposition: String) -> String? {
        guard let range = disposition.range(of: "filename*=", options: .caseInsensitive) else { return nil }
        var value = String(disposition[range.upperBound...])
        if let end = value.firstIndex(of: ";") { value = String(value[..<end]) }
        value = value.trimmingCharacters(in: .whitespaces)
        // ext-value = charset "'" [ language ] "'" value-chars
        let parts = value.split(separator: "'", maxSplits: 2, omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let encoded = String(parts[2])
        guard let decoded = encoded.removingPercentEncoding, !decoded.isEmpty else { return nil }
        return decoded
    }

    /// filename="quoted \" value" or filename=token. Note "filename=" never matches
    /// inside "filename*=" because of the '*' between name and '='.
    static func plainFilename(in disposition: String) -> String? {
        guard let range = disposition.range(of: "filename=", options: .caseInsensitive) else { return nil }
        let rest = disposition[range.upperBound...].drop { $0 == " " || $0 == "\t" }
        guard let first = rest.first else { return nil }
        if first == "\"" {
            var result = ""
            var index = rest.index(after: rest.startIndex)
            while index < rest.endIndex {
                let char = rest[index]
                if char == "\\", rest.index(after: index) < rest.endIndex {
                    index = rest.index(after: index)
                    result.append(rest[index])
                } else if char == "\"" {
                    break
                } else {
                    result.append(char)
                }
                index = rest.index(after: index)
            }
            return result.isEmpty ? nil : result
        }
        var token = String(rest)
        if let end = token.firstIndex(of: ";") { token = String(token[..<end]) }
        token = token.trimmingCharacters(in: .whitespaces)
        return token.isEmpty ? nil : token
    }

    // MARK: - Sanitization

    /// Removes path separators and control characters, avoids hidden/relative names,
    /// and caps the length at `maxFilenameBytes` UTF-8 bytes.
    static func sanitize(_ name: String) -> String {
        var cleaned = ""
        for scalar in name.unicodeScalars {
            switch scalar {
            case "/", "\\", ":": cleaned.append("_")
            case let c where c.value < 0x20 || c.value == 0x7F: continue
            default: cleaned.unicodeScalars.append(scalar)
            }
        }
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        guard !cleaned.isEmpty else { return "" }

        var bytes = 0
        var result = ""
        for char in cleaned {
            bytes += char.utf8.count
            if bytes > maxFilenameBytes { break }
            result.append(char)
        }
        return result
    }
}

/// Wraps raw response bytes for SwiftUI's fileExporter.
struct ResponseBodyDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.data]
    static let writableContentTypes: [UTType] = [.data, .item]

    var data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
