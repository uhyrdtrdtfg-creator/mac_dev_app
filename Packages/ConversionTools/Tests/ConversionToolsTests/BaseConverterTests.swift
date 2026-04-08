import Testing
@testable import ConversionTools

@Test func decimalToBinary() { #expect(BaseConverter.convert("255", from: .decimal, to: .binary) == "11111111") }
@Test func decimalToHex() { #expect(BaseConverter.convert("255", from: .decimal, to: .hex) == "FF") }
@Test func hexToDecimal() { #expect(BaseConverter.convert("FF", from: .hex, to: .decimal) == "255") }
@Test func binaryToOctal() { #expect(BaseConverter.convert("11111111", from: .binary, to: .octal) == "377") }
@Test func baseInvalidInput() { #expect(BaseConverter.convert("ZZZ", from: .decimal, to: .binary) == nil) }
@Test func baseConvertAll() { let r = BaseConverter.convertAll("42", from: .decimal); #expect(r[.binary] == "101010"); #expect(r[.octal] == "52"); #expect(r[.hex] == "2A") }
@Test func hexPrefix() { #expect(BaseConverter.convert("0xFF", from: .hex, to: .decimal) == "255") }
