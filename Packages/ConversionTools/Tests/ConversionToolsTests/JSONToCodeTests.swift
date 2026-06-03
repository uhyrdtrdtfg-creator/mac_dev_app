import XCTest
@testable import ConversionTools

final class JSONToCodeTests: XCTestCase {
    let json = "{\"id\":1,\"name\":\"Ada\",\"active\":true,\"score\":9.5,\"tags\":[\"a\"],\"profile\":{\"age\":30}}"

    func testSwift() {
        guard case .success(let code) = JSONToCode.generate(json: json, language: .swift, rootName: "User") else { return XCTFail() }
        XCTAssertTrue(code.contains("struct User: Codable"))
        XCTAssertTrue(code.contains("let id: Int"))
        XCTAssertTrue(code.contains("let name: String"))
        XCTAssertTrue(code.contains("let active: Bool"))
        XCTAssertTrue(code.contains("let score: Double"))
        XCTAssertTrue(code.contains("let tags: [String]"))
        XCTAssertTrue(code.contains("let profile: Profile"))
        XCTAssertTrue(code.contains("struct Profile"))
    }

    func testTypeScript() {
        guard case .success(let code) = JSONToCode.generate(json: json, language: .typescript, rootName: "User") else { return XCTFail() }
        XCTAssertTrue(code.contains("interface User"))
        XCTAssertTrue(code.contains("id: number;"))
        XCTAssertTrue(code.contains("name: string;"))
        XCTAssertTrue(code.contains("tags: string[];"))
    }

    func testGo() {
        guard case .success(let code) = JSONToCode.generate(json: json, language: .go, rootName: "User") else { return XCTFail() }
        XCTAssertTrue(code.contains("type User struct"))
        XCTAssertTrue(code.contains("Id int `json:\"id\"`"))
        XCTAssertTrue(code.contains("Tags []string `json:\"tags\"`"))
    }

    func testJava() {
        guard case .success(let code) = JSONToCode.generate(json: json, language: .java, rootName: "User") else { return XCTFail() }
        XCTAssertTrue(code.contains("public class User"))
        XCTAssertTrue(code.contains("public int id;"))
        XCTAssertTrue(code.contains("public String name;"))
        XCTAssertTrue(code.contains("public boolean active;"))
        XCTAssertTrue(code.contains("public double score;"))
        XCTAssertTrue(code.contains("public List<String> tags;"))
        XCTAssertTrue(code.contains("public Profile profile;"))
        // Nested class is package-private, not public.
        XCTAssertTrue(code.contains("class Profile"))
        XCTAssertFalse(code.contains("public class Profile"))
    }

    func testPython() {
        guard case .success(let code) = JSONToCode.generate(json: json, language: .python, rootName: "User") else { return XCTFail() }
        XCTAssertTrue(code.contains("from __future__ import annotations"))
        XCTAssertTrue(code.contains("@dataclass"))
        XCTAssertTrue(code.contains("class User:"))
        XCTAssertTrue(code.contains("id: int"))
        XCTAssertTrue(code.contains("name: str"))
        XCTAssertTrue(code.contains("active: bool"))
        XCTAssertTrue(code.contains("score: float"))
        XCTAssertTrue(code.contains("tags: List[str]"))
        XCTAssertTrue(code.contains("profile: Profile"))
        // Nested class must be defined before it's referenced.
        let profileIdx = code.range(of: "class Profile:")!.lowerBound
        let userIdx = code.range(of: "class User:")!.lowerBound
        XCTAssertTrue(profileIdx < userIdx)
    }

    func testInvalidJSON() {
        guard case .failure = JSONToCode.generate(json: "nope", language: .swift) else { return XCTFail() }
    }
}
