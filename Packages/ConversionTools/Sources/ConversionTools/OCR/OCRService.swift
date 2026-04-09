import Foundation
import Vision
import AppKit

public enum OCRService {
    public static func recognizeText(from image: NSImage) async -> Result<String, OCRError> {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return .failure(.invalidImage)
        }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(returning: .failure(.recognitionFailed(error.localizedDescription)))
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: .failure(.noTextFound))
                    return
                }
                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if text.isEmpty {
                    continuation.resume(returning: .failure(.noTextFound))
                } else {
                    continuation.resume(returning: .success(text))
                }
            }
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en-US", "ja", "ko"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: .failure(.recognitionFailed(error.localizedDescription)))
            }
        }
    }

    public static func imageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let image = NSImage(pasteboard: pasteboard) {
            return image
        }
        // Try reading file URLs (e.g., copied image file)
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL],
           let url = urls.first,
           let image = NSImage(contentsOf: url) {
            return image
        }
        return nil
    }
}

public enum OCRError: Error, LocalizedError {
    case invalidImage
    case noTextFound
    case recognitionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidImage: "Invalid image — cannot convert to CGImage"
        case .noTextFound: "No text found in the image"
        case .recognitionFailed(let msg): "Recognition failed: \(msg)"
        }
    }
}
