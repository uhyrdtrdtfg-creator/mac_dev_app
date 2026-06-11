import Testing
import Foundation
@testable import CryptoTools

@Test func md5Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .md5)
    #expect(result == "65a8e27d8879283831b664bd8b7f0ad4")
}

@Test func sha1Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha1)
    #expect(result == "0a0a9f2a6772942557ab5355d76af442f8f65e01")
}

@Test func sha256Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha256)
    #expect(result == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}

@Test func sha512Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha512)
    #expect(result == "374d794a95cdcfd8b35993185fef9ba368f160d8daf432d08ba9f1ed1e5abe6cc69291e0fa2fe0006a52570ef18c19def4e617c33ce52ef0a6e5fbe318cb0387")
}

@Test func emptyStringHash() {
    let result = HashGenerator.hash("", algorithm: .md5)
    #expect(result == "d41d8cd98f00b204e9800998ecf8427e")
}

@Test func crc32Hash() {
    let result = HashGenerator.hash("123456789", algorithm: .crc32)
    #expect(result == "cbf43926")
}

@Test func crc32EmptyString() {
    let result = HashGenerator.hash("", algorithm: .crc32)
    #expect(result == "00000000")
}

@Test func sha3_256EmptyString() {
    let result = HashGenerator.hash("", algorithm: .sha3_256)
    #expect(result == "a7ffc6f8bf1ed76651c14756a061d662f580ff4de43b49fa82d80a4b80f8434a")
}

@Test func sha3_256Hash() {
    let result = HashGenerator.hash("abc", algorithm: .sha3_256)
    #expect(result == "3a985da74fe225b2045c172d6bd390bd855f086e3e9d525b46bfe24511431532")
}

@Test func sha3_512EmptyString() {
    let result = HashGenerator.hash("", algorithm: .sha3_512)
    #expect(result == "a69f73cca23a9ac5c8b567dc185a756e97c982164fe25859e0d1dcc1475c80a615b2123af1f5f94c11e3e9402c3ac558f500199d95b6d3e301758586281dcd26")
}

@Test func sha3_512Hash() {
    let result = HashGenerator.hash("abc", algorithm: .sha3_512)
    #expect(result == "b751850b1a57168a5693cd924b6b096e08f621827444f70d884f5d0240d2712e10e116e9192af3c91a7ec57647e3934057340b4cf408d5a56592f8274eec53f0")
}

@Test func sha3LongInputSpansMultipleBlocks() {
    let result256 = HashGenerator.hash(String(repeating: "a", count: 200), algorithm: .sha3_256)
    #expect(result256.count == 64)
    let result512 = HashGenerator.hash(String(repeating: "a", count: 200), algorithm: .sha3_512)
    #expect(result512.count == 128)
}

@Test func hashAllAlgorithms() {
    let results = HashGenerator.hashAll("test")
    #expect(results.count == 7)
    #expect(results[.md5] != nil)
    #expect(results[.sha1] != nil)
    #expect(results[.sha256] != nil)
    #expect(results[.sha512] != nil)
    #expect(results[.sha3_256] != nil)
    #expect(results[.sha3_512] != nil)
    #expect(results[.crc32] != nil)
}

@Test func hashData() {
    let data = Data("Hello, World!".utf8)
    let result = HashGenerator.hash(data: data, algorithm: .sha256)
    #expect(result == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}
