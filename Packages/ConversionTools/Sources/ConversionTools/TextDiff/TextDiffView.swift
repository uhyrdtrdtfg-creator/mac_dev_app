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
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("Paste text in both panels — differences highlight below")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
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
                .buttonStyle(.bordered).controlSize(.small)
                Button("Clear") {
                    leftText = ""; rightText = ""
                }
                .buttonStyle(.bordered).controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Two editable panels
            HStack(spacing: 0) {
                // Left: Original
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("ORIGINAL")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: leftText)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.fill.tertiary)
                    Divider()
                    TextEditor(text: $leftText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                }

                Divider()

                // Right: Modified
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("MODIFIED")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                        Spacer()
                        CopyButton(text: rightText)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(.fill.tertiary)
                    Divider()
                    TextEditor(text: $rightText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                }
            }
            .frame(maxHeight: .infinity)

            // Diff result
            if !diffLines.isEmpty {
                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(diffLines) { line in
                            HStack(spacing: 0) {
                                Text(line.leftLineNumber.map { String($0) } ?? "")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 32, alignment: .trailing)
                                    .padding(.trailing, 4)

                                Text(line.type == .added ? "+" : line.type == .removed ? "−" : " ")
                                    .font(.system(.caption, design: .monospaced))
                                    .fontWeight(.bold)
                                    .foregroundStyle(colorFor(line.type))
                                    .frame(width: 16)

                                Text(line.rightLineNumber.map { String($0) } ?? "")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .frame(width: 32, alignment: .trailing)
                                    .padding(.trailing, 8)

                                Text(line.text.isEmpty ? " " : line.text)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(line.type == .equal ? .primary : colorFor(line.type))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 1)
                            .padding(.horizontal, 8)
                            .background(bgFor(line.type))
                        }
                    }
                    .padding(6)
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onChange(of: leftText) { _, _ in computeDiff() }
        .onChange(of: rightText) { _, _ in computeDiff() }
    }

    private func colorFor(_ type: DiffLineType) -> Color {
        switch type { case .equal: .primary; case .added: .green; case .removed: .red }
    }

    private func bgFor(_ type: DiffLineType) -> Color {
        switch type { case .equal: .clear; case .added: .green.opacity(0.08); case .removed: .red.opacity(0.08) }
    }

    private func computeDiff() {
        if leftText.isEmpty && rightText.isEmpty { diffLines = []; stats = nil; return }
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
