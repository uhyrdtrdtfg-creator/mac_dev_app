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

@Test func hashAllAlgorithms() {
    let results = HashGenerator.hashAll("test")
    #expect(results.count == 4)
    #expect(results[.md5] != nil)
    #expect(results[.sha1] != nil)
    #expect(results[.sha256] != nil)
    #expect(results[.sha512] != nil)
}

@Test func hashData() {
    let data = Data("Hello, World!".utf8)
    let result = HashGenerator.hash(data: data, algorithm: .sha256)
    #expect(result == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}
