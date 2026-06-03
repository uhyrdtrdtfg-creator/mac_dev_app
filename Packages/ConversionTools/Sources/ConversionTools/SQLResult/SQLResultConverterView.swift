import SwiftUI
import AppKit
import DevAppCore

public struct SQLResultConverterView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case csv = "CSV"
        case insert = "INSERT"
        case update = "UPDATE"
        var id: String { rawValue }
    }

    @Environment(\.toolHandoff) private var handoff
    @State private var input = ""
    @State private var mode: Mode = .csv
    @State private var tableName = "my_table"
    @State private var keyColumn = ""
    @State private var output = ""
    @State private var table: SQLResultTable?
    @State private var status: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("SQL Result → CSV / SQL").font(.title2).fontWeight(.semibold)
                Text("Paste a MySQL/psql result table and convert it to CSV, INSERT or UPDATE statements")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Output", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 240)

                if mode != .csv {
                    HStack(spacing: 6) {
                        Text("Table").font(.caption).foregroundStyle(.secondary)
                        TextField("my_table", text: $tableName)
                            .textFieldStyle(.plain).frame(width: 140)
                            .padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }

                if mode == .update, let columns = table?.columns, !columns.isEmpty {
                    HStack(spacing: 6) {
                        Text("Key").font(.caption).foregroundStyle(.secondary)
                        Picker("Key", selection: $keyColumn) {
                            ForEach(columns, id: \.self) { Text($0).tag($0) }
                        }.labelsHidden().fixedSize()
                    }
                }

                Spacer()
                if let table {
                    Text("\(table.columns.count) cols × \(table.rows.count) rows")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                Button { exportExcel() } label: {
                    Label("Export Excel", systemImage: "tablecells.badge.ellipsis")
                }
                .buttonStyle(.bordered)
                .disabled(table == nil)
            }

            if let status {
                Text(status).font(.caption).foregroundStyle(.green)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("MySQL / psql Result").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 300)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(mode.rawValue).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 300)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onAppear {
            if let incoming = handoff.consume("sql-result") { input = incoming; reparse() }
        }
        .onChange(of: input) { _, _ in reparse() }
        .onChange(of: mode) { _, _ in regenerate() }
        .onChange(of: tableName) { _, _ in regenerate() }
        .onChange(of: keyColumn) { _, _ in regenerate() }
    }

    private func reparse() {
        table = SQLResultConverter.parse(input)
        if let detected = SQLResultConverter.parseTableName(input) {
            tableName = detected
        }
        if let columns = table?.columns, !columns.isEmpty, !columns.contains(keyColumn) {
            keyColumn = columns.first { $0.lowercased() == "id" } ?? columns[0]
        }
        regenerate()
    }

    private func exportExcel() {
        guard let table else { return }
        let sheet = SQLResultConverter.parseTableName(input) ?? "Sheet1"
        let data = XLSXExporter.build(columns: table.columns, rows: table.rows, sheetName: String(sheet.prefix(31)))
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.init(filenameExtension: "xlsx")!]
        panel.nameFieldStringValue = "\(SQLResultConverter.parseTableName(input) ?? "export").xlsx"
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url); status = "已导出 \(url.lastPathComponent)（\(table.rows.count) 行）" }
            catch { status = "导出失败：\(error.localizedDescription)" }
        }
    }

    private func regenerate() {
        guard let table else { output = ""; return }
        switch mode {
        case .csv: output = SQLResultConverter.toCSV(table)
        case .insert: output = SQLResultConverter.toInsert(table, tableName: tableName)
        case .update: output = SQLResultConverter.toUpdate(table, tableName: tableName, keyColumn: keyColumn)
        }
    }
}

extension SQLResultConverterView {
    public static let descriptor = ToolDescriptor(
        id: "sql-result",
        name: "SQL Result → CSV/SQL",
        icon: "tablecells.fill",
        category: .developer,
        searchKeywords: ["sql", "mysql", "result", "csv", "insert", "update", "table", "结果", "导出", "语句"]
    )
}
