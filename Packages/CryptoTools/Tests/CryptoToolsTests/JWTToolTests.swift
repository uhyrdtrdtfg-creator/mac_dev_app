import XCTest
@testable import CryptoTools

final class JWTToolTests: XCTestCase {
    // Canonical jwt.io HS256 example.
    let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
    let secret = "your-256-bit-secret"

    func testDecodeHeaderAndPayload() throws {
        let decoded = try JWTTool.decode(token)
        XCTAssertEqual(decoded.algorithm, "HS256")
        XCTAssertEqual(decoded.type, "JWT")
        XCTAssertTrue(decoded.payloadJSON.contains("\"sub\""))
        XCTAssertTrue(decoded.payloadJSON.contains("1234567890"))
    }

    func testVerifyValidSignature() {
        XCTAssertEqual(JWTTool.verify(token, key: secret), .valid)
    }

    func testVerifyWrongSecret() {
        XCTAssertEqual(JWTTool.verify(token, key: "wrong"), .invalid)
    }

    func testMissingKey() {
        XCTAssertEqual(JWTTool.verify(token, key: ""), .missingKey)
    }

    func testMalformedThrows() {
        XCTAssertThrowsError(try JWTTool.decode("not-a-jwt"))
    }

    func testInterpretsIatClaim() throws {
        let decoded = try JWTTool.decode(token)
        XCTAssertTrue(decoded.claims.contains { $0.key.contains("iat") })
    }
}
