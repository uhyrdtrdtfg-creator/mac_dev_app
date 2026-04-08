import Testing
@testable import ConversionTools

@Test func analyzeBasic() {
    let stats = TextAnalyzer.analyze("Hello World")
    #expect(stats.characters == 11)
    #expect(stats.words == 2)
    #expect(stats.lines == 1)
}

@Test func analyzeNoSpaces() {
    let stats = TextAnalyzer.analyze("Hello World")
    #expect(stats.charactersNoSpaces == 10)
}

@Test func analyzeMultiline() {
    let stats = TextAnalyzer.analyze("Line 1\nLine 2\nLine 3")
    #expect(stats.lines == 3)
    #expect(stats.words == 6)
}

@Test func analyzeSentences() {
    let stats = TextAnalyzer.analyze("Hello. How are you? I'm fine!")
    #expect(stats.sentences == 3)
}

@Test func analyzeEmpty() {
    let stats = TextAnalyzer.analyze("")
    #expect(stats.characters == 0)
    #expect(stats.words == 0)
    #expect(stats.lines == 0)
}

@Test func analyzeBytes() {
    let stats = TextAnalyzer.analyze("你好")
    #expect(stats.characters == 2)
    #expect(stats.bytes == 6) // UTF-8: 3 bytes per Chinese character
}
