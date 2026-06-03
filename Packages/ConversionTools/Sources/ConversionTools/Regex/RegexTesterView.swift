import SwiftUI
import DevAppCore

public struct RegexTesterView: View {
    @Environment(\.toolHandoff) private var handoff
    @State private var pattern = ""
    @State private var text = ""
    @State private var replacement = ""
    @State private var options = RegexOptions()
    @State private var matches: [RegexMatch] = []
    @State private var errorMessage: String?
    @State private var replaced = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Regex Tester").font(.title2).fontWeight(.semibold)
                Text("Test regular expressions with live matches, capture groups and replacement")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack {
                Text("/").foregroundStyle(.tertiary)
                TextField("pattern", text: $pattern)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                Text("/").foregroundStyle(.tertiary)
                if let errorMessage {
                    Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red).lineLimit(1)
                } else {
                    Text("\(matches.count) match\(matches.count == 1 ? "" : "es")").font(.caption).foregroundStyle(.green)
                }
            }
            .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 16) {
                Toggle("i (ignore case)", isOn: $options.caseInsensitive).toggleStyle(.checkbox)
                Toggle("s (dot ⊃ \\n)", isOn: $options.dotMatchesNewlines).toggleStyle(.checkbox)
                Toggle("m (multiline)", isOn: $options.anchorsMatchLines).toggleStyle(.checkbox)
                Toggle("x (comments)", isOn: $options.allowComments).toggleStyle(.checkbox)
            }
            .font(.caption)

            VStack(alignment: .leading, spacing: 4) {
                Text("Test String").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !matches.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Matches").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(matches.enumerated()), id: \.element.id) { idx, match in
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text("#\(idx + 1)").font(.caption).foregroundStyle(.tertiary)
                                        Text(match.value).font(.system(.body, design: .monospaced)).foregroundStyle(.primary)
                                        Spacer()
                                        Text("\(match.range.lowerBound)–\(match.range.upperBound)").font(.caption2).foregroundStyle(.tertiary)
                                    }
                                    ForEach(match.groups) { group in
                                        HStack {
                                            Text("  ↳ \(group.name ?? "group \(group.index)")").font(.caption).foregroundStyle(.secondary)
                                            Text(group.value).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue)
                                        }
                                    }
                                }
                                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Replacement (use $1, $2…)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    if !replaced.isEmpty { CopyButton(text: replaced) }
                }
                TextField("replacement template", text: $replacement)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                if !replaced.isEmpty {
                    Text(replaced).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding()
        .onAppear {
            if let incoming = handoff.consume("regex-tester") { text = incoming; run() }
        }
        .onChange(of: pattern) { _, _ in run() }
        .onChange(of: text) { _, _ in run() }
        .onChange(of: replacement) { _, _ in run() }
        .onChange(of: options.caseInsensitive) { _, _ in run() }
        .onChange(of: options.dotMatchesNewlines) { _, _ in run() }
        .onChange(of: options.anchorsMatchLines) { _, _ in run() }
        .onChange(of: options.allowComments) { _, _ in run() }
    }

    private func run() {
        switch RegexTester.matches(pattern: pattern, in: text, options: options) {
        case .success(let m): matches = m; errorMessage = nil
        case .failure(let e): matches = []; errorMessage = e.localizedDescription
        }
        if !replacement.isEmpty, errorMessage == nil, case .success(let r) = RegexTester.replace(pattern: pattern, in: text, template: replacement, options: options) {
            replaced = r
        } else {
            replaced = ""
        }
    }
}

extension RegexTesterView {
    public static let descriptor = ToolDescriptor(
        id: "regex-tester",
        name: "Regex Tester",
        icon: "asterisk",
        category: .developer,
        searchKeywords: ["regex", "regexp", "regular expression", "match", "pattern", "正则", "匹配"]
    )
}
