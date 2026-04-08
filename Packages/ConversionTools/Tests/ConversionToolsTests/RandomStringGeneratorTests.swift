import Testing
@testable import ConversionTools

@Test func randomStringDefaultLength() { #expect(RandomStringGenerator.generate(RandomStringOptions()).count == 16) }
@Test func randomStringCustomLength() { #expect(RandomStringGenerator.generate(RandomStringOptions(length: 32)).count == 32) }
@Test func randomStringOnlyDigits() { let r = RandomStringGenerator.generate(RandomStringOptions(length: 100, uppercase: false, lowercase: false, digits: true, special: false)); #expect(r.allSatisfy { $0.isNumber }) }
@Test func randomStringBatch() { #expect(RandomStringGenerator.generateBatch(5, options: RandomStringOptions()).count == 5) }
