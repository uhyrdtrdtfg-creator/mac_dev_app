import Testing
import Foundation
@testable import DevAppCore

@Test func dataToHexLowercase() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(data.hexString(uppercase: false) == "deadbeef")
}

@Test func dataToHexUppercase() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(data.hexString(uppercase: true) == "DEADBEEF")
}

@Test func hexToData() {
    let hex = "deadbeef"
    let data = Data(hexString: hex)
    #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
}

@Test func hexToDataUppercase() {
    let hex = "DEADBEEF"
    let data = Data(hexString: hex)
    #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
}

@Test func hexToDataInvalidReturnsNil() {
    let hex = "zzzz"
    let data = Data(hexString: hex)
    #expect(data == nil)
}

@Test func hexToDataOddLengthReturnsNil() {
    let hex = "abc"
    let data = Data(hexString: hex)
    #expect(data == nil)
}

@Test func emptyDataToHex() {
    let data = Data()
    #expect(data.hexString(uppercase: false) == "")
}
