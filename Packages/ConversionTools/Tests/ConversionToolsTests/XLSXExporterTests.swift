import XCTest
@testable import ConversionTools

final class XLSXExporterTests: XCTestCase {
    func testColumnLetters() {
        XCTAssertEqual(XLSXExporter.columnLetter(0), "A")
        XCTAssertEqual(XLSXExporter.columnLetter(25), "Z")
        XCTAssertEqual(XLSXExporter.columnLetter(26), "AA")
        XCTAssertEqual(XLSXExporter.columnLetter(27), "AB")
        XCTAssertEqual(XLSXExporter.columnLetter(701), "ZZ")
    }

    func testIsValidZipContainer() {
        let data = XLSXExporter.build(columns: ["id", "name"], rows: [["1", "Alice"]])
        let bytes = [UInt8](data)
        // ZIP local file header magic PK\x03\x04.
        XCTAssertEqual(Array(bytes.prefix(4)), [0x50, 0x4B, 0x03, 0x04])
        // End-of-central-directory signature PK\x05\x06 present near the tail.
        XCTAssertTrue(containsSubsequence(bytes, [0x50, 0x4B, 0x05, 0x06]))
    }

    func testContainsCellData() {
        // STORED entries are uncompressed, so cell text appears verbatim in the bytes.
        let data = XLSXExporter.build(columns: ["id", "name"], rows: [["1", "Alice"], ["2", "Bob"]])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("Sheet1") || text.contains("workbook"))
        XCTAssertTrue(text.contains("Alice"))
        XCTAssertTrue(text.contains("Bob"))
        XCTAssertTrue(text.contains("<v>1</v>"))            // numeric cell
        XCTAssertTrue(text.contains("inlineStr"))           // string cell
    }

    func testNullAndEmptyBecomeBlankCells() {
        let data = XLSXExporter.build(columns: ["a", "b"], rows: [["NULL", ""]])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("/>")) // self-closed empty cell
        XCTAssertFalse(text.contains(">NULL<"))
    }

    func testXMLEscaping() {
        let data = XLSXExporter.build(columns: ["x"], rows: [["a<b>&\"c"]])
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("a&lt;b&gt;&amp;&quot;c"))
    }

    private func containsSubsequence(_ haystack: [UInt8], _ needle: [UInt8]) -> Bool {
        guard haystack.count >= needle.count else { return false }
        for i in 0...(haystack.count - needle.count) where Array(haystack[i..<i + needle.count]) == needle {
            return true
        }
        return false
    }
}
