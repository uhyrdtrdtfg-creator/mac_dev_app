import Foundation
import UniformTypeIdentifiers

public enum MultipartEncoderError: Error, LocalizedError, Equatable {
    case unreadableFile(partName: String, path: String)

    public var errorDescription: String? {
        switch self {
        case .unreadableFile(let name, let path):
            "Multipart part \"\(name)\": file is missing or unreadable at \(path)"
        }
    }
}

public enum MultipartEncoder {
    public static func generateBoundary() -> String {
        "DevToolkit-\(UUID().uuidString)"
    }

    /// Escapes quotes and backslashes for Content-Disposition name/filename values (RFC 2388 practice).
    static func escapeDispositionValue(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    /// MIME type from the path's file extension via UTType, with application/octet-stream fallback.
    public static func mimeType(forPath path: String) -> String {
        let ext = (path as NSString).pathExtension
        guard !ext.isEmpty, let type = UTType(filenameExtension: ext), let mime = type.preferredMIMEType else {
            return "application/octet-stream"
        }
        return mime
    }

    /// Builds a spec-correct multipart/form-data payload with CRLF line endings throughout.
    /// File parts are read from disk at encode time; a missing/unreadable file throws.
    public static func encode(parts: [MultipartPart], boundary: String) throws -> Data {
        var data = Data()
        for part in parts where part.isEnabled {
            data.append(Data("--\(boundary)\r\n".utf8))
            switch part.kind {
            case .text(let value):
                data.append(Data("Content-Disposition: form-data; name=\"\(escapeDispositionValue(part.name))\"\r\n\r\n".utf8))
                data.append(Data(value.utf8))
            case .file(let path, let filename, let mimeType):
                let resolvedFilename = filename.isEmpty ? (path as NSString).lastPathComponent : filename
                data.append(Data("Content-Disposition: form-data; name=\"\(escapeDispositionValue(part.name))\"; filename=\"\(escapeDispositionValue(resolvedFilename))\"\r\n".utf8))
                data.append(Data("Content-Type: \(mimeType.isEmpty ? "application/octet-stream" : mimeType)\r\n\r\n".utf8))
                guard FileManager.default.fileExists(atPath: path),
                      let fileData = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
                    throw MultipartEncoderError.unreadableFile(partName: part.name, path: path)
                }
                data.append(fileData)
            }
            data.append(Data("\r\n".utf8))
        }
        data.append(Data("--\(boundary)--\r\n".utf8))
        return data
    }

    /// Extracts the boundary parameter from a Content-Type header value, if present.
    public static func boundary(fromContentType contentType: String) -> String? {
        for param in contentType.split(separator: ";").dropFirst() {
            let trimmed = param.trimmingCharacters(in: .whitespaces)
            guard trimmed.lowercased().hasPrefix("boundary=") else { continue }
            var value = String(trimmed.dropFirst("boundary=".count))
            if value.count >= 2, value.hasPrefix("\""), value.hasSuffix("\"") {
                value = String(value.dropFirst().dropLast())
            }
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// Encodes parts into the request body and reconciles the Content-Type boundary:
    /// a user-set Content-Type wins, but if it lacks a boundary the generated one is appended.
    public static func apply(parts: [MultipartPart], to request: inout URLRequest) throws {
        let existing = request.value(forHTTPHeaderField: "Content-Type")
        let boundary = existing.flatMap { Self.boundary(fromContentType: $0) } ?? generateBoundary()
        request.httpBody = try encode(parts: parts, boundary: boundary)
        if let existing {
            if Self.boundary(fromContentType: existing) == nil {
                request.setValue("\(existing); boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            }
        } else {
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        }
    }
}

public enum BinaryBodyError: Error, LocalizedError, Equatable {
    case noFileSelected
    case fileUnreadable(path: String)

    public var errorDescription: String? {
        switch self {
        case .noFileSelected: "Binary body: no file selected"
        case .fileUnreadable(let path): "Binary body file is missing or unreadable: \(path)"
        }
    }
}

public enum BinaryBodyFile {
    /// Reads the binary body file at send time; throws a clear error when missing.
    public static func load(path: String) throws -> Data {
        guard !path.isEmpty else { throw BinaryBodyError.noFileSelected }
        guard FileManager.default.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else {
            throw BinaryBodyError.fileUnreadable(path: path)
        }
        return data
    }

    /// Writes restored binary bytes to a temp file so the editor has a real path to reference.
    public static func writeTemporary(_ data: Data) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DevToolkitBinaryBodies", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("binary-body-\(UUID().uuidString)")
        try data.write(to: url)
        return url.path
    }

    /// Appends a Content-Type header for the binary body unless the user already set one.
    public static func headers(_ headers: [KeyValuePair], addingContentType mimeType: String) -> [KeyValuePair] {
        guard !mimeType.isEmpty,
              !headers.contains(where: { $0.isEnabled && $0.key.caseInsensitiveCompare("Content-Type") == .orderedSame })
        else { return headers }
        return headers + [KeyValuePair(key: "Content-Type", value: mimeType)]
    }
}
