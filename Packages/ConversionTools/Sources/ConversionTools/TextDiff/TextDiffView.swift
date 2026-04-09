import SwiftUI
import DevAppCore

public struct TextDiffView: View {
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffLines: [DiffLine] = []
    @State private var stats: DiffEngine.DiffStats?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header + stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Text Diff")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Paste text in both panels — differences highlight automatically")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if let stats {
                    HStack(spacing: 12) {
                        Label("\(stats.additions)", systemImage: "plus")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.green)
                        Label("\(stats.deletions)", systemImage: "minus")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.red)
                        Label("\(stats.unchanged)", systemImage: "equal")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                    }
                }

                Button("Swap") {
                    let tmp = leftText; leftText = rightText; rightText = tmp
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Clear") {
                    leftText = ""; rightText = ""
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Side-by-side panels
            HStack(spacing: 0) {
                // Left panel: Original
                VStack(alignment: .leading, spacing: 0) {
                    Text("ORIGINAL")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary)

                    Divider()

                    ZStack {
                        // Diff highlight background layer
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                let leftLines = buildLeftLines()
                                ForEach(Array(leftLines.enumerated()), id: \.offset) { idx, entry in
                                    HStack(spacing: 0) {
                                        Text("\(idx + 1)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 32, alignment: .trailing)
                                            .padding(.trailing, 6)
                                        Text(entry.text.isEmpty ? " " : entry.text)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(entry.type == .removed ? .red : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 4)
                                    .background(entry.type == .removed ? Color.red.opacity(0.1) : .clear)
                                }
                            }
                            .padding(6)
                        }

                        // Editable text layer (transparent, on top)
                        TextEditor(text: $leftText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(.leading, 42) // offset for line numbers
                            .padding(6)
                            .opacity(0.01) // nearly invisible but captures input
                    }
                }

                Divider()

                // Right panel: Modified
                VStack(alignment: .leading, spacing: 0) {
                    Text("MODIFIED")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary)

                    Divider()

                    ZStack {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                let rightLines = buildRightLines()
                                ForEach(Array(rightLines.enumerated()), id: \.offset) { idx, entry in
                                    HStack(spacing: 0) {
                                        Text("\(idx + 1)")
                                            .font(.system(.caption2, design: .monospaced))
                                            .foregroundStyle(.tertiary)
                                            .frame(width: 32, alignment: .trailing)
                                            .padding(.trailing, 6)
                                        Text(entry.text.isEmpty ? " " : entry.text)
                                            .font(.system(.body, design: .monospaced))
                                            .foregroundStyle(entry.type == .added ? .green : .primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(.vertical, 1)
                                    .padding(.horizontal, 4)
                                    .background(entry.type == .added ? Color.green.opacity(0.1) : .clear)
                                }
                            }
                            .padding(6)
                        }

                        TextEditor(text: $rightText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(.leading, 42)
                            .padding(6)
                            .opacity(0.01)
                    }
                }
            }
        }
        .onChange(of: leftText) { _, _ in computeDiff() }
        .onChange(of: rightText) { _, _ in computeDiff() }
    }

    // MARK: - Build display lines

    private struct DisplayLine {
        let text: String
        let type: DiffLineType
    }

    private func buildLeftLines() -> [DisplayLine] {
        if diffLines.isEmpty {
            return leftText.components(separatedBy: "\n").map { DisplayLine(text: $0, type: .equal) }
        }
        return diffLines.compactMap { line in
            switch line.type {
            case .equal: DisplayLine(text: line.text, type: .equal)
            case .removed: DisplayLine(text: line.text, type: .removed)
            case .added: nil // added lines don't appear in left panel
            }
        }
    }

    private func buildRightLines() -> [DisplayLine] {
        if diffLines.isEmpty {
            return rightText.components(separatedBy: "\n").map { DisplayLine(text: $0, type: .equal) }
        }
        return diffLines.compactMap { line in
            switch line.type {
            case .equal: DisplayLine(text: line.text, type: .equal)
            case .added: DisplayLine(text: line.text, type: .added)
            case .removed: nil // removed lines don't appear in right panel
            }
        }
    }

    private func computeDiff() {
        if leftText.isEmpty && rightText.isEmpty {
            diffLines = []; stats = nil; return
        }
        diffLines = DiffEngine.diff(old: leftText, new: rightText)
        stats = DiffEngine.stats(from: diffLines)
    }
}

extension TextDiffView {
    public static let descriptor = ToolDescriptor(
        id: "text-diff",
        name: "Text Diff",
        icon: "doc.text.magnifyingglass",
        category: .conversion,
        searchKeywords: ["diff", "compare", "text", "difference", "对比", "比较"]
    )
}
