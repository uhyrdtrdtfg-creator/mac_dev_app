import SwiftUI
import AppKit

struct JSONTreeView: View {
    let jsonString: String
    @State private var model: DisplayModel?
    @State private var expanded: Set<String> = ["$"]

    var body: some View {
        Group {
            if let model {
                switch model.content {
                case .tree(let root, let containerPaths, let nodeCount):
                    treeView(root: root, containerPaths: containerPaths, nodeCount: nodeCount)
                case .fallback(let text, let notice):
                    fallbackView(text: text, notice: notice)
                }
            } else {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task(id: jsonString) {
            let source = jsonString
            model = await Task.detached(priority: .userInitiated) { DisplayModel(jsonString: source) }.value
            expanded = ["$"]
        }
    }

    // MARK: - Tree

    @ViewBuilder
    private func treeView(root: JSONTreeNode, containerPaths: Set<String>, nodeCount: Int) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    expanded = containerPaths
                } label: {
                    Label("Expand All", systemImage: "chevron.down.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Button {
                    expanded = []
                } label: {
                    Label("Collapse All", systemImage: "chevron.right.square")
                        .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Text("\(nodeCount) nodes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            List(flatten(root)) { row in
                rowView(row)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 1, leading: 8, bottom: 1, trailing: 8))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func flatten(_ root: JSONTreeNode) -> [Row] {
        var rows: [Row] = []
        func walk(_ node: JSONTreeNode, depth: Int) {
            rows.append(Row(id: node.path, depth: depth, kind: .node(node)))
            if let children = node.children, expanded.contains(node.path) {
                for child in children { walk(child, depth: depth + 1) }
                if node.omittedChildren > 0 {
                    rows.append(Row(id: node.path + " +more", depth: depth + 1, kind: .more(node.omittedChildren)))
                }
            }
        }
        walk(root, depth: 0)
        return rows
    }

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        switch row.kind {
        case .node(let node):
            HStack(spacing: 5) {
                if node.isContainer {
                    Button {
                        if expanded.contains(node.path) { expanded.remove(node.path) } else { expanded.insert(node.path) }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(expanded.contains(node.path) ? 90 : 0))
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }

                Text(node.key)
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.blue)

                if node.isContainer {
                    Text(containerSummary(node))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                } else {
                    Text(":")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(scalarDisplay(node.value))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(scalarColor(node.value))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                Spacer(minLength: 0)
            }
            .padding(.leading, CGFloat(row.depth) * 16)
            .contentShape(Rectangle())
            .contextMenu {
                Button("Copy Value") { copyToPasteboard(copyValueText(node)) }
                Button("Copy Path") { copyToPasteboard(node.path) }
            }
        case .more(let count):
            Text("… +\(count) more")
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.leading, CGFloat(row.depth) * 16 + 17)
        }
    }

    private func containerSummary(_ node: JSONTreeNode) -> String {
        switch node.value {
        case .object: "{\(node.totalChildCount)}"
        case .array: "[\(node.totalChildCount)]"
        default: ""
        }
    }

    private func scalarDisplay(_ value: JSONValue) -> String {
        switch value {
        case .string(let s): JSONValue.quote(s)
        default: value.scalarText ?? ""
        }
    }

    private func scalarColor(_ value: JSONValue) -> Color {
        switch value {
        case .string: .green
        case .number: .purple
        case .bool: .orange
        default: .secondary
        }
    }

    private func copyValueText(_ node: JSONTreeNode) -> String {
        node.value.scalarText ?? node.value.prettyPrinted()
    }

    private func copyToPasteboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    // MARK: - Fallback

    @ViewBuilder
    private func fallbackView(text: String, notice: String?) -> some View {
        VStack(spacing: 0) {
            if let notice {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(notice)
                    Spacer()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.yellow.opacity(0.12))
            }
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Model

    private struct Row: Identifiable {
        let id: String
        let depth: Int
        let kind: Kind
        enum Kind { case node(JSONTreeNode), more(Int) }
    }

    private struct DisplayModel: Sendable {
        enum Content: Sendable {
            case tree(root: JSONTreeNode, containerPaths: Set<String>, nodeCount: Int)
            case fallback(text: String, notice: String?)
        }
        let content: Content

        init(jsonString: String) {
            switch JSONTreeModel.build(jsonString: jsonString) {
            case .tree(let root, let nodeCount):
                var paths: Set<String> = []
                func collect(_ node: JSONTreeNode) {
                    guard let children = node.children else { return }
                    paths.insert(node.path)
                    for child in children { collect(child) }
                }
                collect(root)
                content = .tree(root: root, containerPaths: paths, nodeCount: nodeCount)
            case .documentTooLarge:
                content = .fallback(text: Self.prettyText(jsonString), notice: "Response is larger than 2 MB — showing formatted text instead of a tree.")
            case .tooManyNodes:
                content = .fallback(text: Self.prettyText(jsonString), notice: "JSON has more than \(JSONTreeLimits.maxNodeCount) nodes — showing formatted text instead of a tree.")
            case .invalid:
                content = .fallback(text: Self.prettyText(jsonString), notice: nil)
            }
        }

        static func prettyText(_ jsonString: String) -> String {
            guard let data = jsonString.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data),
                  let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
                  let result = String(data: pretty, encoding: .utf8) else { return jsonString }
            return result
        }
    }
}
