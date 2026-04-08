import Testing
@testable import ConversionTools

@Test func asciiToHex() { #expect(HexAsciiConverter.asciiToHex("ABC", separator: "") == "414243") }
@Test func asciiToHexWithSpace() { #expect(HexAsciiConverter.asciiToHex("Hi", separator: " ") == "48 69") }
@Test func hexToAscii() { #expect(HexAsciiConverter.hexToAscii("48656C6C6F") == "Hello") }
@Test func hexToAsciiWithSpaces() { #expect(HexAsciiConverter.hexToAscii("48 65 6C 6C 6F") == "Hello") }
@Test func hexToAsciiInvalid() { #expect(HexAsciiConverter.hexToAscii("ZZZ") == nil) }
@Test func hexToAsciiOddLength() { #expect(HexAsciiConverter.hexToAscii("ABC") == nil) }
