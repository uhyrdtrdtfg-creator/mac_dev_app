import Testing
@testable import ConversionTools

@Test func loremWords() {
    let result = LoremIpsumGenerator.generate(count: 10, unit: .words)
    let words = result.split(separator: " ")
    #expect(words.count == 10)
}

@Test func loremSentences() {
    let result = LoremIpsumGenerator.generate(count: 3, unit: .sentences)
    let sentences = result.components(separatedBy: ".").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    #expect(sentences.count == 3)
}

@Test func loremParagraphs() {
    let result = LoremIpsumGenerator.generate(count: 2, unit: .paragraphs)
    let paragraphs = result.components(separatedBy: "\n\n")
    #expect(paragraphs.count == 2)
}

@Test func loremNotEmpty() {
    #expect(!LoremIpsumGenerator.generate(count: 1, unit: .words).isEmpty)
}
