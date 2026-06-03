import Foundation
import CoreImage
import AppKit
import Vision

public enum QRCorrectionLevel: String, CaseIterable, Identifiable, Sendable {
    case low = "L"        // ~7%
    case medium = "M"     // ~15%
    case quartile = "Q"   // ~25%
    case high = "H"       // ~30%
    public var id: String { rawValue }
}

public enum QRCodeService {
    /// Generate a QR code image for the given text.
    public static func generate(from text: String, correction: QRCorrectionLevel = .medium, scale: CGFloat = 10, foreground: NSColor = .black, background: NSColor = .white) -> NSImage? {
        guard !text.isEmpty else { return nil }
        let context = CIContext()
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data(text.utf8), forKey: "inputMessage")
        filter.setValue(correction.rawValue, forKey: "inputCorrectionLevel")
        guard var output = filter.outputImage else { return nil }

        // Recolor: false → background, true → foreground.
        if let colorFilter = CIFilter(name: "CIFalseColor") {
            colorFilter.setValue(output, forKey: kCIInputImageKey)
            colorFilter.setValue(CIColor(color: foreground) ?? CIColor.black, forKey: "inputColor0")
            colorFilter.setValue(CIColor(color: background) ?? CIColor.white, forKey: "inputColor1")
            if let colored = colorFilter.outputImage { output = colored }
        }

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: scaled.extent.width, height: scaled.extent.height))
    }

    /// Decode any QR / barcode payloads found in the image.
    public static func decode(from image: NSImage) async -> [String] {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return [] }
        return await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let payloads = (request.results as? [VNBarcodeObservation])?.compactMap { $0.payloadStringValue } ?? []
                continuation.resume(returning: payloads)
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do { try handler.perform([request]) }
            catch { continuation.resume(returning: []) }
        }
    }

    /// Write a QR image to disk as PNG.
    public static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
