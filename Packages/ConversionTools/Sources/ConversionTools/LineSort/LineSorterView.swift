import SwiftUI
import DevAppCore

public struct LineSorterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var mode: LineSortMode = .ascending
    public init() {}
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Line Sort & Deduplicate").font(.title2).fontWeight(.bold)
                Text("Sort, reverse, shuffle, and deduplicate lines of text").font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Picker("Mode", selection: $mode) { ForEach(LineSortMode.allCases) { m in Text(m.rawValue).tag(m) } }.pickerStyle(.segmented).fixedSize()
                Button("Sort") { output = LineSorter.sort(input, mode: mode) }.buttonStyle(.borderedProminent)
                Button("Deduplicate") { output = LineSorter.deduplicate(input) }.buttonStyle(.bordered)
                Spacer()
                let stats = LineSorter.stats(input)
                Text("\(stats.total) lines, \(stats.unique) unique, \(stats.duplicates) dupes").font(.caption).foregroundStyle(.secondary)
            }
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Input").font(.caption).fontWeight(.medium).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                }
                Image(systemName: "arrow.right").font(.title3).foregroundStyle(.tertiary).frame(width: 20)
                VStack(alignment: .leading, spacing: 6) {
                    HStack { Text("Output").font(.caption).fontWeight(.medium).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: output) }
                    TextEditor(text: .constant(output)).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(10).background(.background.secondary).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary, lineWidth: 1))
                }
            }
        }.padding(20)
    }
}

extension LineSorterView {
    public static let descriptor = ToolDescriptor(id: "line-sort", name: "Line Sort & Deduplicate", icon: "line.3.horizontal.decrease", category: .conversion, searchKeywords: ["sort", "line", "deduplicate", "unique", "reverse", "排序", "去重"])
}
