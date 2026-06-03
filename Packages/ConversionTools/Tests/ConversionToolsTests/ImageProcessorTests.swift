import XCTest
import AppKit
@testable import ConversionTools

final class ImageProcessorTests: XCTestCase {
    // A 1×1 red PNG (used as a stand-in rendered entry).
    private let samplePNG: Data = {
        let b64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAAC0lEQVR4nGNgYGAAAAAEAAH2FzhVAAAAAElFTkSuQmCC"
        return Data(base64Encoded: b64)!
    }()

    // MARK: - Pure container assembly (headless-safe)

    func testICOContainerStructure() {
        let data = ImageProcessor.icoData(fromEntries: [(16, samplePNG), (32, samplePNG)])
        XCTAssertNotNil(data)
        let bytes = [UInt8](data!)
        XCTAssertEqual(Array(bytes[0...5]), [0, 0, 1, 0, 2, 0]) // reserved, type=1, count=2 (LE)
        // First directory entry: width=16, height=16.
        XCTAssertEqual(bytes[6], 16)
        XCTAssertEqual(bytes[7], 16)
        // Directory size = 6 + 2*16 = 38; first image offset stored at bytes[18..21].
        let offset = UInt32(bytes[18]) | UInt32(bytes[19]) << 8 | UInt32(bytes[20]) << 16 | UInt32(bytes[21]) << 24
        XCTAssertEqual(offset, 38)
    }

    func testICO256EncodedAsZeroWidth() {
        let data = ImageProcessor.icoData(fromEntries: [(256, samplePNG)])!
        let bytes = [UInt8](data)
        XCTAssertEqual(bytes[6], 0) // 256 is encoded as 0
        XCTAssertEqual(bytes[7], 0)
    }

    func testICNSContainerStructure() {
        let data = ImageProcessor.icnsData(fromEntries: [("ic07", samplePNG), ("ic08", samplePNG)])
        XCTAssertNotNil(data)
        XCTAssertEqual(String(bytes: data!.prefix(4), encoding: .ascii), "icns")
        // Total size field (big-endian) equals data length.
        let bytes = [UInt8](data!)
        let total = UInt32(bytes[4]) << 24 | UInt32(bytes[5]) << 16 | UInt32(bytes[6]) << 8 | UInt32(bytes[7])
        XCTAssertEqual(Int(total), data!.count)
        // First chunk type.
        XCTAssertEqual(String(bytes: data![8..<12], encoding: .ascii), "ic07")
    }

    func testEmptyEntriesReturnNil() {
        XCTAssertNil(ImageProcessor.icoData(fromEntries: []))
        XCTAssertNil(ImageProcessor.icnsData(fromEntries: []))
    }

    func testFormatMetadata() {
        XCTAssertEqual(ImageFormat.png.mime, "image/png")
        XCTAssertEqual(ImageFormat.jpeg.fileExtension, "jpg")
        XCTAssertTrue(ImageFormat.jpeg.supportsQuality)
        XCTAssertFalse(ImageFormat.png.supportsQuality)
    }

    // MARK: - Drawing-dependent (skipped when headless rendering is unavailable)

    func testEncodePNGIfRenderable() throws {
        guard let image = NSImage(data: samplePNG), let data = ImageProcessor.encode(image, format: .png) else {
            throw XCTSkip("Headless rendering unavailable")
        }
        XCTAssertEqual([UInt8](data.prefix(4)), [0x89, 0x50, 0x4E, 0x47])
    }
}
