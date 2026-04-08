import SwiftUI
import DevAppCore

public struct TextAnalyzerView: View {
    @State private var input = ""
    @State private var stats = TextAnalyzer.analyze("")
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Text Analyzer").font(.title2).fontWeight(.bold)
                Text("Count characters, words, lines, sentences, and more").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                statCard("Characters", "\(stats.characters)")
                statCard("No Spaces", "\(stats.charactersNoSpaces)")
                statCard("Words", "\(stats.words)")
                statCard("Lines", "\(stats.lines)")
                statCard("Sentences", "\(stats.sentences)")
                statCard("Paragraphs", "\(stats.paragraphs)")
                statCard("Bytes", "\(stats.bytes)")
            }
            TextEditor(text: $input)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.background.secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
        }
        .padding(20)
        .onChange(of: input) { _, _ in stats = TextAnalyzer.analyze(input) }
    }

    private func statCard(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(.title2, design: .rounded)).fontWeight(.bold).foregroundStyle(.blue)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
        .padding(10)
        .background(.background.secondary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

extension TextAnalyzerView {
    public static let descriptor = ToolDescriptor(id: "text-analyzer", name: "Text Analyzer", icon: "text.magnifyingglass", category: .conversion, searchKeywords: ["text", "count", "word", "character", "line", "analyze", "字数", "统计"])
}
