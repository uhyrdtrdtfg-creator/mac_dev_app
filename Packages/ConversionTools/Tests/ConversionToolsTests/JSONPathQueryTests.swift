import XCTest
@testable import ConversionTools

final class JSONPathQueryTests: XCTestCase {
    let json = "{\"users\":[{\"id\":1,\"name\":\"Alice\"},{\"id\":2,\"name\":\"Bob\"}],\"count\":2}"

    func testRootKey() {
        let r = JSONPathQuery.query(json, path: "$.count")
        XCTAssertEqual(r.output, "2")
    }

    func testArrayIndex() {
        let r = JSONPathQuery.query(json, path: "$.users[0].name")
        XCTAssertEqual(r.output, "\"Alice\"")
    }

    func testWildcard() {
        let r = JSONPathQuery.query(json, path: "$.users[*].id")
        XCTAssertNotNil(r.output)
        XCTAssertTrue(r.output!.contains("1"))
        XCTAssertTrue(r.output!.contains("2"))
    }

    func testBracketKey() {
        let r = JSONPathQuery.query(json, path: "$[\"count\"]")
        XCTAssertEqual(r.output, "2")
    }

    func testInvalidJSON() {
        let r = JSONPathQuery.query("nope", path: "$.x")
        XCTAssertNotNil(r.error)
    }
}
