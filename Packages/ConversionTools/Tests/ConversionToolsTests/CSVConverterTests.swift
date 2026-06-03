import XCTest
@testable import ConversionTools

final class CSVConverterTests: XCTestCase {
    func testJSONToCSV() {
        let json = "[{\"name\":\"Alice\",\"age\":30},{\"name\":\"Bob\",\"age\":25}]"
        guard case .success(let csv) = CSVConverter.jsonToCSV(json) else { return XCTFail() }
        XCTAssertEqual(csv, "age,name\n30,Alice\n25,Bob")
    }

    func testCSVToJSONRoundTrip() {
        let csv = "name,age\nAlice,30\nBob,25"
        guard case .success(let json) = CSVConverter.csvToJSON(csv) else { return XCTFail() }
        XCTAssertTrue(json.contains("\"Alice\""))
        XCTAssertTrue(json.contains("30"))
    }

    func testQuotedFieldWithComma() {
        let csv = "name,note\n\"Doe, John\",hi"
        guard case .success(let json) = CSVConverter.csvToJSON(csv) else { return XCTFail() }
        XCTAssertTrue(json.contains("Doe, John"))
    }

    func testEscapesDelimiterOnExport() {
        let json = "[{\"a\":\"x,y\"}]"
        guard case .success(let csv) = CSVConverter.jsonToCSV(json) else { return XCTFail() }
        XCTAssertTrue(csv.contains("\"x,y\""))
    }

    func testInvalidJSON() {
        guard case .failure = CSVConverter.jsonToCSV("not json") else { return XCTFail() }
    }
}
