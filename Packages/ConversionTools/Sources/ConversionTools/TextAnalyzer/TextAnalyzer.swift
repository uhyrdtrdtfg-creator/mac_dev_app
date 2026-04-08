import Foundation

public struct TextStats: Sendable {
    public let characters: Int
    public let charactersNoSpaces: Int
    public let words: Int
    public let lines: Int
    public let sentences: Int
    public let paragraphs: Int
    public let bytes: Int
}

public enum TextAnalyzer {
    public static func analyze(_ input: String) -> TextStats {
        let characters = input.count
        let charactersNoSpaces = input.filter { !$0.isWhitespace }.count
        let words = input.split { $0.isWhitespace || $0.isNewline }.count
        let lines = input.isEmpty ? 0 : input.components(separatedBy: "\n").count
        let sentences = input.components(separatedBy: CharacterSet(charactersIn: ".!?")).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        let paragraphs = input.isEmpty ? 0 : input.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
        let bytes = input.utf8.count
        return TextStats(characters: characters, charactersNoSpaces: charactersNoSpaces, words: words, lines: lines, sentences: sentences, paragraphs: paragraphs, bytes: bytes)
    }
}
