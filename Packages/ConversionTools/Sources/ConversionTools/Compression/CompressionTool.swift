import Foundation
import Compression

public enum CompressionAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case zlib = "zlib (deflate)"
    case lzfse = "LZFSE"
    case lz4 = "LZ4"
    case lzma = "LZMA"

    public var id: String { rawValue }

    var raw: compression_algorithm {
        switch self {
        case .zlib: COMPRESSION_ZLIB
        case .lzfse: COMPRESSION_LZFSE
        case .lz4: COMPRESSION_LZ4
        case .lzma: COMPRESSION_LZMA
        }
    }
}

public enum CompressionError: Error, LocalizedError {
    case empty
    case compressionFailed
    case decompressionFailed
    case invalidBase64

    public var errorDescription: String? {
        switch self {
        case .empty: "Nothing to process"
        case .compressionFailed: "Compression failed"
        case .decompressionFailed: "Decompression failed (wrong algorithm or corrupt data?)"
        case .invalidBase64: "Input is not valid Base64"
        }
    }
}

public struct CompressionResult: Sendable {
    public let base64: String
    public let originalBytes: Int
    public let compressedBytes: Int
    public var ratio: Double { originalBytes == 0 ? 0 : Double(compressedBytes) / Double(originalBytes) }
}

public enum CompressionTool {
    /// Compress UTF-8 text and return Base64 plus size stats.
    public static func compress(text: String, algorithm: CompressionAlgorithm) throws -> CompressionResult {
        let source = Data(text.utf8)
        guard !source.isEmpty else { throw CompressionError.empty }
        let compressed = try perform(source, operation: COMPRESSION_STREAM_ENCODE, algorithm: algorithm.raw, dstHint: source.count + 4096)
        return CompressionResult(base64: compressed.base64EncodedString(), originalBytes: source.count, compressedBytes: compressed.count)
    }

    /// Decode Base64, decompress, and return UTF-8 text.
    public static func decompress(base64: String, algorithm: CompressionAlgorithm) throws -> String {
        let trimmed = base64.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CompressionError.empty }
        guard let data = Data(base64Encoded: trimmed) else { throw CompressionError.invalidBase64 }
        let decompressed = try perform(data, operation: COMPRESSION_STREAM_DECODE, algorithm: algorithm.raw, dstHint: max(data.count * 8, 65_536))
        guard let text = String(data: decompressed, encoding: .utf8) else { throw CompressionError.decompressionFailed }
        return text
    }

    private static func perform(_ input: Data, operation: compression_stream_operation, algorithm: compression_algorithm, dstHint: Int) throws -> Data {
        let streamPointer = UnsafeMutablePointer<compression_stream>.allocate(capacity: 1)
        defer { streamPointer.deallocate() }
        var stream = streamPointer.pointee
        var status = compression_stream_init(&stream, operation, algorithm)
        guard status == COMPRESSION_STATUS_OK else {
            throw operation == COMPRESSION_STREAM_ENCODE ? CompressionError.compressionFailed : CompressionError.decompressionFailed
        }
        defer { compression_stream_destroy(&stream) }

        let dstCapacity = max(dstHint, 4096)
        let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: dstCapacity)
        defer { dstBuffer.deallocate() }

        var output = Data()
        let result: Data? = input.withUnsafeBytes { (rawPtr: UnsafeRawBufferPointer) -> Data? in
            guard let srcBase = rawPtr.bindMemory(to: UInt8.self).baseAddress else { return nil }
            stream.src_ptr = srcBase
            stream.src_size = input.count
            stream.dst_ptr = dstBuffer
            stream.dst_size = dstCapacity

            let flags = Int32(COMPRESSION_STREAM_FINALIZE.rawValue)
            repeat {
                status = compression_stream_process(&stream, flags)
                switch status {
                case COMPRESSION_STATUS_OK, COMPRESSION_STATUS_END:
                    let produced = dstCapacity - stream.dst_size
                    output.append(dstBuffer, count: produced)
                    stream.dst_ptr = dstBuffer
                    stream.dst_size = dstCapacity
                default:
                    return nil
                }
            } while status == COMPRESSION_STATUS_OK
            return output
        }

        guard let result else {
            throw operation == COMPRESSION_STREAM_ENCODE ? CompressionError.compressionFailed : CompressionError.decompressionFailed
        }
        return result
    }
}
