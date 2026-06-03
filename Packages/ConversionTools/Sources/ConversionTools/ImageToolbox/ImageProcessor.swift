import Foundation
import AppKit
import ImageIO
import UniformTypeIdentifiers

public enum ImageFormat: String, CaseIterable, Identifiable, Sendable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case heic = "HEIC"
    public var id: String { rawValue }

    public var fileExtension: String {
        switch self {
        case .png: "png"; case .jpeg: "jpg"; case .tiff: "tiff"; case .heic: "heic"
        }
    }
    public var mime: String {
        switch self {
        case .png: "image/png"; case .jpeg: "image/jpeg"; case .tiff: "image/tiff"; case .heic: "image/heic"
        }
    }
    public var supportsQuality: Bool { self == .jpeg || self == .heic }
}

public enum ImageProcessor {
    public static func pixelSize(of image: NSImage) -> (width: Int, height: Int) {
        if let rep = image.representations.first {
            return (rep.pixelsWide, rep.pixelsHigh)
        }
        return (Int(image.size.width), Int(image.size.height))
    }

    /// Encode an image to the chosen format. `quality` (0...1) applies to JPEG/HEIC.
    public static func encode(_ image: NSImage, format: ImageFormat, quality: Double = 0.8) -> Data? {
        switch format {
        case .png, .jpeg, .tiff:
            guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
            let type: NSBitmapImageRep.FileType = format == .png ? .png : (format == .jpeg ? .jpeg : .tiff)
            var props: [NSBitmapImageRep.PropertyKey: Any] = [:]
            if format == .jpeg { props[.compressionFactor] = quality }
            return rep.representation(using: type, properties: props)
        case .heic:
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, UTType.heic.identifier as CFString, 1, nil) else { return nil }
            CGImageDestinationAddImage(dest, cgImage, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { return nil }
            return data as Data
        }
    }

    /// Build a `data:` URL string for the image.
    public static func dataURL(_ image: NSImage, format: ImageFormat, quality: Double = 0.8) -> String? {
        guard let data = encode(image, format: format, quality: quality) else { return nil }
        return "data:\(format.mime);base64,\(data.base64EncodedString())"
    }

    /// Render the image to an exact square pixel size and return PNG data.
    public static func pngData(_ image: NSImage, pixelSize size: Int) -> Data? {
        guard size > 0,
              let rep = NSBitmapImageRep(
                bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: size, height: size)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: size, height: size),
                   from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()

        return rep.representation(using: .png, properties: [:])
    }

    /// Build a multi-resolution Windows `.ico` (PNG-compressed entries).
    public static func icoData(_ image: NSImage, sizes: [Int] = [16, 32, 48, 64, 128, 256]) -> Data? {
        let entries: [(size: Int, png: Data)] = sizes.compactMap { s in
            guard let png = pngData(image, pixelSize: s) else { return nil }
            return (s, png)
        }
        return icoData(fromEntries: entries)
    }

    /// Assemble a `.ico` container from already-rendered PNG entries (pure, no drawing).
    public static func icoData(fromEntries entries: [(size: Int, png: Data)]) -> Data? {
        guard !entries.isEmpty else { return nil }

        var header = Data()
        header.append(le16(0))                       // reserved
        header.append(le16(1))                       // type = icon
        header.append(le16(UInt16(entries.count)))   // image count

        let directorySize = 6 + entries.count * 16
        var offset = directorySize
        var directory = Data()
        var images = Data()
        for entry in entries {
            directory.append(UInt8(entry.size >= 256 ? 0 : entry.size)) // width (0 = 256)
            directory.append(UInt8(entry.size >= 256 ? 0 : entry.size)) // height
            directory.append(0)                                          // palette
            directory.append(0)                                          // reserved
            directory.append(le16(1))                                    // planes
            directory.append(le16(32))                                   // bpp
            directory.append(le32(UInt32(entry.png.count)))              // size
            directory.append(le32(UInt32(offset)))                       // offset
            offset += entry.png.count
            images.append(entry.png)
        }
        return header + directory + images
    }

    /// Build a macOS `.icns` from the image (PNG entries for 128/256/512/1024).
    public static func icnsData(_ image: NSImage) -> Data? {
        // OSType → pixel size.
        let map: [(type: String, size: Int)] = [
            ("ic07", 128), ("ic08", 256), ("ic09", 512), ("ic10", 1024)
        ]
        let entries: [(type: String, png: Data)] = map.compactMap { entry in
            guard let png = pngData(image, pixelSize: entry.size) else { return nil }
            return (entry.type, png)
        }
        return icnsData(fromEntries: entries)
    }

    /// Assemble an `.icns` container from already-rendered PNG entries (pure, no drawing).
    public static func icnsData(fromEntries entries: [(type: String, png: Data)]) -> Data? {
        var body = Data()
        for entry in entries {
            body.append(contentsOf: Array(entry.type.utf8))   // OSType (4 bytes)
            body.append(be32(UInt32(entry.png.count + 8)))    // length incl. 8-byte header
            body.append(entry.png)
        }
        guard !body.isEmpty else { return nil }

        var file = Data()
        file.append(contentsOf: Array("icns".utf8))
        file.append(be32(UInt32(body.count + 8)))
        file.append(body)
        return file
    }

    // MARK: - Endian helpers

    private static func le16(_ v: UInt16) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func le32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.littleEndian) { Data($0) } }
    private static func be32(_ v: UInt32) -> Data { withUnsafeBytes(of: v.bigEndian) { Data($0) } }
}
