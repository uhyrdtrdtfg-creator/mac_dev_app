import XCTest
@testable import ConversionTools

final class TOMLConverterTests: XCTestCase {
    func testScalarsAndTable() {
        let toml = """
        title = "My App"
        port = 8080

        [database]
        host = "localhost"
        enabled = true
        """
        guard case .success(let json) = TOMLConverter.tomlToJSON(toml) else { return XCTFail() }
        XCTAssertTrue(json.contains("\"title\""))
        XCTAssertTrue(json.contains("8080"))
        XCTAssertTrue(json.contains("\"host\""))
    }

    func testJSONToTOML() {
        let json = "{\"name\":\"x\",\"count\":3,\"nested\":{\"a\":1}}"
        guard case .success(let toml) = TOMLConverter.jsonToTOML(json) else { return XCTFail() }
        XCTAssertTrue(toml.contains("name = \"x\""))
        XCTAssertTrue(toml.contains("count = 3"))
        XCTAssertTrue(toml.contains("[nested]"))
    }

    func testScalarArray() {
        let toml = "ports = [80, 443, 8080]"
        guard case .success(let json) = TOMLConverter.tomlToJSON(toml) else { return XCTFail() }
        XCTAssertTrue(json.contains("80"))
        XCTAssertTrue(json.contains("443"))
    }

    func testArrayOfTables() {
        let toml = """
        [[servers]]
        name = "alpha"

        [[servers]]
        name = "beta"
        """
        guard case .success(let json) = TOMLConverter.tomlToJSON(toml) else { return XCTFail() }
        XCTAssertTrue(json.contains("alpha"))
        XCTAssertTrue(json.contains("beta"))
    }
}
