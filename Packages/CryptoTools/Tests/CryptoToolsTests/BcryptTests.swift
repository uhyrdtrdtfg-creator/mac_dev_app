import Foundation
import Testing
@testable import CryptoTools

struct BcryptTests {
    // Canonical OpenBSD/crypt_blowfish reference vectors.
    @Test func verifyKnownVectorUStarU() throws {
        #expect(try Bcrypt.verify(password: "U*U", hash: "$2a$05$CCCCCCCCCCCCCCCCCCCCC.E5YPO9kmyuRGyh0XouQYb4YMJKvyOeW"))
    }

    @Test func verifyKnownVectorUStarUStar() throws {
        #expect(try Bcrypt.verify(password: "U*U*", hash: "$2a$05$CCCCCCCCCCCCCCCCCCCCC.VGOzA784oUp/Z0DY336zx7pLYAy0lwK"))
    }

    @Test func verifyKnownVectorUStarUStarU() throws {
        #expect(try Bcrypt.verify(password: "U*U*U", hash: "$2a$05$XXXXXXXXXXXXXXXXXXXXXOAcXxm9kjPGEMsLznoKqmqw7tc8WCx4a"))
    }

    // jBCrypt reference vectors.
    @Test func verifyKnownVectorAlphabet() throws {
        #expect(try Bcrypt.verify(password: "abcdefghijklmnopqrstuvwxyz", hash: "$2a$06$.rCVZVOThsIa97pEDOxvGuRRgzG64bvtJ0938xuqzv18d3ZpQhstC"))
    }

    @Test func verifyKnownVectorEmptyPassword() throws {
        #expect(try Bcrypt.verify(password: "", hash: "$2a$06$DCq7YPn5Rq63x1Lad4cll.TV4S6ytwfsfvkgY8jIucDrjc8deX1s."))
    }

    @Test func hashVerifyRoundTrip() throws {
        let hash = try Bcrypt.hash(password: "correct horse battery staple", cost: 4)
        #expect(hash.hasPrefix("$2b$04$"))
        #expect(hash.count == 60)
        #expect(try Bcrypt.verify(password: "correct horse battery staple", hash: hash))
    }

    @Test func wrongPasswordFails() throws {
        let hash = try Bcrypt.hash(password: "secret", cost: 4)
        #expect(try !Bcrypt.verify(password: "Secret", hash: hash))
    }

    @Test func costOutOfRangeThrows() {
        #expect(throws: BcryptError.self) { try Bcrypt.hash(password: "pw", cost: 3) }
        #expect(throws: BcryptError.self) { try Bcrypt.hash(password: "pw", cost: 16) }
    }

    @Test func malformedHashThrows() {
        #expect(throws: BcryptError.self) { try Bcrypt.verify(password: "pw", hash: "not a hash") }
        #expect(throws: BcryptError.self) { try Bcrypt.verify(password: "pw", hash: "$2y$04$TnjywYklQbbZjdjBgBoA4e9G7RJt9blgMgsCvUvus4Iv4TENB5nHy") }
        #expect(throws: BcryptError.self) { try Bcrypt.verify(password: "pw", hash: "$2b$04$tooshort") }
    }

    @Test func invalidSaltLengthThrows() {
        #expect(throws: BcryptError.self) { try Bcrypt.hash(password: "pw", cost: 4, salt: Data(repeating: 1, count: 8)) }
    }

    @Test func fixedSaltIsDeterministic() throws {
        let salt = Data((0..<16).map { UInt8($0) })
        let a = try Bcrypt.hash(password: "pw", cost: 5, salt: salt)
        let b = try Bcrypt.hash(password: "pw", cost: 5, salt: salt)
        #expect(a == b)
        #expect(try Bcrypt.verify(password: "pw", hash: a))
    }

    @Test func randomSaltsDiffer() throws {
        let a = try Bcrypt.hash(password: "pw", cost: 4)
        let b = try Bcrypt.hash(password: "pw", cost: 4)
        #expect(a != b)
        #expect(try Bcrypt.verify(password: "pw", hash: b))
    }
}
