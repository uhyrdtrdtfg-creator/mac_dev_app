import SwiftUI
import DevAppCore

public struct UnicodeInspectorView: View {
    @Environment(\.toolHandoff) private var handoff
    @State private var input = "Hi 👋🏽 café"
    @State private var scalars: [UnicodeScalarInfo] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unicode Inspector").font(.title2).fontWeight(.semibold)
                Text("Break text into Unicode scalars with code points, names, categories and byte encodings")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            TextEditor(text: $input)
                .font(.system(.title3, design: .monospaced)).scrollContentBackground(.hidden)
                .frame(minHeight: 70)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Text("\(scalars.count) scalar\(scalars.count == 1 ? "" : "s")").font(.caption).foregroundStyle(.secondary)
                if scalars.contains(where: { $0.isInvisible }) {
                    Label("Contains invisible/zero-width characters", systemImage: "eye.slash")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            ScrollView {
                VStack(spacing: 4) {
                    ForEach(scalars) { info in
                        HStack(spacing: 10) {
                            Text(info.isInvisible ? "□" : info.character)
                                .font(.system(size: 20))
                                .frame(width: 32, height: 32)
                                .background((info.isInvisible ? Color.orange : Color.blue).opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(info.name).font(.caption).foregroundStyle(.primary).lineLimit(1)
                                Text(info.category).font(.caption2).foregroundStyle(.tertiary)
                            }
                            .frame(width: 220, alignment: .leading)
                            Text(info.codePoint).font(.system(.caption, design: .monospaced)).foregroundStyle(.blue).frame(width: 80, alignment: .leading)
                            VStack(alignment: .leading, spacing: 1) {
                                Text("UTF-8: \(info.utf8)").font(.caption2).foregroundStyle(.secondary)
                                Text("UTF-16: \(info.utf16)").font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .onAppear {
            if let incoming = handoff.consume("unicode-inspector") { input = incoming }
            scalars = UnicodeInspector.inspect(input)
        }
        .onChange(of: input) { _, _ in scalars = UnicodeInspector.inspect(input) }
    }
}

extension UnicodeInspectorView {
    public static let descriptor = ToolDescriptor(
        id: "unicode-inspector",
        name: "Unicode Inspector",
        icon: "character.magnify",
        category: .developer,
        searchKeywords: ["unicode", "codepoint", "utf8", "utf16", "character", "emoji", "invisible", "字符", "码点"]
    )
}
