import Foundation

public enum LoremUnit: String, CaseIterable, Identifiable, Sendable {
    case words = "Words"
    case sentences = "Sentences"
    case paragraphs = "Paragraphs"
    public var id: String { rawValue }
}

public enum LoremIpsumGenerator {
    private static let loremWords = [
        "lorem", "ipsum", "dolor", "sit", "amet", "consectetur", "adipiscing", "elit",
        "sed", "do", "eiusmod", "tempor", "incididunt", "ut", "labore", "et", "dolore",
        "magna", "aliqua", "enim", "ad", "minim", "veniam", "quis", "nostrud",
        "exercitation", "ullamco", "laboris", "nisi", "aliquip", "ex", "ea", "commodo",
        "consequat", "duis", "aute", "irure", "in", "reprehenderit", "voluptate",
        "velit", "esse", "cillum", "fugiat", "nulla", "pariatur", "excepteur", "sint",
        "occaecat", "cupidatat", "non", "proident", "sunt", "culpa", "qui", "officia",
        "deserunt", "mollit", "anim", "id", "est", "laborum", "perspiciatis", "unde",
        "omnis", "iste", "natus", "error", "voluptatem", "accusantium", "doloremque",
        "laudantium", "totam", "rem", "aperiam", "eaque", "ipsa", "quae", "ab", "illo",
        "inventore", "veritatis", "quasi", "architecto", "beatae", "vitae", "dicta",
        "explicabo", "nemo", "ipsam", "quia", "voluptas", "aspernatur", "aut", "odit",
        "fugit", "consequuntur", "magni", "dolores", "eos", "ratione", "sequi", "nesciunt"
    ]

    public static func generate(count: Int, unit: LoremUnit) -> String {
        switch unit {
        case .words: return generateWords(count)
        case .sentences: return (0..<count).map { _ in generateSentence() }.joined(separator: " ")
        case .paragraphs: return (0..<count).map { _ in generateParagraph() }.joined(separator: "\n\n")
        }
    }

    private static func generateWords(_ count: Int) -> String {
        (0..<count).map { _ in loremWords.randomElement()! }.joined(separator: " ")
    }

    private static func generateSentence() -> String {
        let wordCount = Int.random(in: 8...16)
        var words = (0..<wordCount).map { _ in loremWords.randomElement()! }
        words[0] = words[0].capitalized
        return words.joined(separator: " ") + "."
    }

    private static func generateParagraph() -> String {
        let sentenceCount = Int.random(in: 3...6)
        return (0..<sentenceCount).map { _ in generateSentence() }.joined(separator: " ")
    }
}
