import XCTest
@testable import CryptoTools

final class TOTPGeneratorTests: XCTestCase {
    // RFC 6238 test seed "12345678901234567890" in Base32.
    let secret = "GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ"

    func testBase32Decode() {
        let data = TOTPGenerator.base32Decode(secret)
        XCTAssertEqual(data, Data("12345678901234567890".utf8))
    }

    func testBase32DecodeLowercaseAndSpaces() {
        XCTAssertEqual(TOTPGenerator.base32Decode("jbsw y3dp"), TOTPGenerator.base32Decode("JBSWY3DP"))
    }

    func testRFC6238_SHA1_T59() {
        let code = TOTPGenerator.generate(secretBase32: secret, algorithm: .sha1, digits: 8, period: 30,
                                          date: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code, "94287082")
    }

    func testRFC6238_SHA1_T1111111109() {
        let code = TOTPGenerator.generate(secretBase32: secret, algorithm: .sha1, digits: 8, period: 30,
                                          date: Date(timeIntervalSince1970: 1111111109))
        XCTAssertEqual(code, "07081804")
    }

    func testDigitsPadding() {
        let code = TOTPGenerator.generate(secretBase32: secret, digits: 6, date: Date(timeIntervalSince1970: 59))
        XCTAssertEqual(code?.count, 6)
    }

    func testInvalidSecretReturnsNil() {
        XCTAssertNil(TOTPGenerator.generate(secretBase32: "10"))  // '1' and '0' not in Base32 alphabet
    }

    func testRemainingSeconds() {
        XCTAssertEqual(TOTPGenerator.remainingSeconds(period: 30, date: Date(timeIntervalSince1970: 0)), 30)
        XCTAssertEqual(TOTPGenerator.remainingSeconds(period: 30, date: Date(timeIntervalSince1970: 10)), 20)
    }

    func testParseOTPAuth() {
        let uri = "otpauth://totp/ACME:alice@acme.com?secret=JBSWY3DPEHPK3PXP&issuer=ACME&digits=8&period=60&algorithm=SHA256"
        let config = TOTPGenerator.parseOTPAuth(uri)
        XCTAssertEqual(config?.secret, "JBSWY3DPEHPK3PXP")
        XCTAssertEqual(config?.issuer, "ACME")
        XCTAssertEqual(config?.digits, 8)
        XCTAssertEqual(config?.period, 60)
        XCTAssertEqual(config?.algorithm, .sha256)
    }
}
