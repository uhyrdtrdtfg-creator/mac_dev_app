import SwiftUI
import DevAppCore

public struct TextDiffView: View {
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var diffLines: [DiffLine] = []
    @State private var stats: DiffEngine.DiffStats?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Text Diff")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Compare two texts side by side and highlight differences")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // Stats + Compare button
            HStack(spacing: 12) {
                Button("Compare") {
                    computeDiff()
                }
                .buttonStyle(.borderedProminent)

                Button("Swap") {
                    let tmp = leftText; leftText = rightText; rightText = tmp
                    computeDiff()
                }
                .buttonStyle(.bordered)

                Button("Clear") {
                    leftText = ""; rightText = ""; diffLines = []; stats = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                if let stats {
                    HStack(spacing: 12) {
                        Label("\(stats.additions) added", systemImage: "plus")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Label("\(stats.deletions) removed", systemImage: "minus")
                            .font(.caption)
                            .foregroundStyle(.red)
                        Label("\(stats.unchanged) unchanged", systemImage: "equal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 20)

            if diffLines.isEmpty {
                // Input mode
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("ORIGINAL")
                                .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                            Spacer()
                            CopyButton(text: leftText)
                        }
                        TextEditor(text: $leftText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("MODIFIED")
                                .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                            Spacer()
                            CopyButton(text: rightText)
                        }
                        TextEditor(text: $rightText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .background(.background.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            } else {
                // Diff result view
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(diffLines) { line in
                            diffLineRow(line)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
        }
    }

    private func diffLineRow(_ line: DiffLine) -> some View {
        HStack(spacing: 0) {
            // Left line number
            Text(line.leftLineNumber.map { String($0) } ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 4)

            // Type indicator
            Text(line.type == .added ? "+" : line.type == .removed ? "-" : " ")
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(colorForType(line.type))
                .frame(width: 16)

            // Right line number
            Text(line.rightLineNumber.map { String($0) } ?? "")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .frame(width: 36, alignment: .trailing)
                .padding(.trailing, 8)

            // Content
            Text(line.text)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(line.type == .equal ? .primary : colorForType(line.type))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 8)
        .background(backgroundForType(line.type))
    }

    private func colorForType(_ type: DiffLineType) -> Color {
        switch type {
        case .equal: .primary
        case .added: .green
        case .removed: .red
        }
    }

    private func backgroundForType(_ type: DiffLineType) -> Color {
        switch type {
        case .equal: .clear
        case .added: .green.opacity(0.08)
        case .removed: .red.opacity(0.08)
        }
    }

    private func computeDiff() {
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
