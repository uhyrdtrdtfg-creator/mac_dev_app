import XCTest
@testable import CryptoTools

final class KeyDerivationTests: XCTestCase {
    // RFC 6070 PBKDF2-HMAC-SHA1 test vector: P="password", S="salt", c=1, dkLen=20.
    func testPBKDF2RFC6070() throws {
        let data = try KeyDerivation.pbkdf2(password: "password", salt: "salt", iterations: 1, keyLength: 20, hash: .sha1)
        XCTAssertEqual(KeyDerivation.format(data, as: .hex), "0c60c80f961f0e71f3a9b524af6012062fe037a6")
    }

    // RFC 6070: c=2.
    func testPBKDF2Iterations2() throws {
        let data = try KeyDerivation.pbkdf2(password: "password", salt: "salt", iterations: 2, keyLength: 20, hash: .sha1)
        XCTAssertEqual(KeyDerivation.format(data, as: .hex), "ea6c014dc72d6f8ccd1ed92ace1d41f0d8de8957")
    }

    func testPBKDF2OutputLength() throws {
        let data = try KeyDerivation.pbkdf2(password: "pw", salt: "salt", iterations: 1000, keyLength: 32, hash: .sha256)
        XCTAssertEqual(data.count, 32)
    }

    func testHKDFDeterministicLength() throws {
        let a = try KeyDerivation.hkdf(secret: "secret", salt: "salt", info: "ctx", keyLength: 42, hash: .sha256)
        let b = try KeyDerivation.hkdf(secret: "secret", salt: "salt", info: "ctx", keyLength: 42, hash: .sha256)
        XCTAssertEqual(a.count, 42)
        XCTAssertEqual(a, b)
    }

    func testInvalidLengthThrows() {
        XCTAssertThrowsError(try KeyDerivation.pbkdf2(password: "pw", salt: "s", iterations: 1, keyLength: 0, hash: .sha256))
    }
}
