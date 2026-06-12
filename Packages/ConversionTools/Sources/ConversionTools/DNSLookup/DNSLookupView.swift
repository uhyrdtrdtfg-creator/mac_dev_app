import SwiftUI
import DevAppCore

public struct DNSLookupView: View {
    @State private var hostname = "example.com"
    @State private var recordType: DNSRecordType = .a
    @State private var serverID = "google"
    @State private var answers: [DNSRecord] = []
    @State private var authority: [DNSRecord] = []
    @State private var queryInfo: String?
    @State private var errorMessage: String?
    @State private var isQuerying = false
    @State private var hasQueried = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DNS Lookup").font(.title2).fontWeight(.semibold)
                Text("Query DNS records over raw UDP/TCP, like dig — A, AAAA, CNAME, MX, TXT, NS, SOA, PTR and CAA")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                TextField("Hostname or IP address (IP switches to PTR reverse lookup)", text: $hostname)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { runQuery() }

                Picker("", selection: $recordType) {
                    ForEach(DNSRecordType.allCases) { type in
                        Text(type.name).tag(type)
                    }
                }
                .labelsHidden().fixedSize()

                Picker("", selection: $serverID) {
                    ForEach(DNSServerPreset.presets) { preset in
                        Text(preset.name).tag(preset.id)
                    }
                }
                .labelsHidden().fixedSize()

                Button {
                    runQuery()
                } label: {
                    if isQuerying {
                        ProgressView().controlSize(.small).frame(width: 44)
                    } else {
                        Text("Query").frame(width: 44)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isQuerying || hostname.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.callout).foregroundStyle(.red)
            } else if let queryInfo {
                Label(queryInfo, systemImage: "clock").font(.callout).foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !answers.isEmpty {
                        recordSection("Answers", records: answers)
                    }
                    if !authority.isEmpty {
                        recordSection("Authority", records: authority)
                    }
                    if hasQueried && !isQuerying && answers.isEmpty && authority.isEmpty && errorMessage == nil {
                        Text("No records returned").font(.callout).foregroundStyle(.tertiary)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding()
        .onChange(of: hostname) { _, newValue in
            if DNSLookupEngine.reverseName(forIP: newValue.trimmingCharacters(in: .whitespaces)) != nil {
                recordType = .ptr
            }
        }
    }

    private func recordSection(_ title: String, records: [DNSRecord]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            ForEach(records) { record in
                HStack(spacing: 10) {
                    Text(record.name)
                        .font(.system(.callout, design: .monospaced))
                        .frame(minWidth: 140, alignment: .leading)
                        .textSelection(.enabled)
                    Text(record.type)
                        .font(.caption).fontWeight(.medium)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(.tint.opacity(0.15)).clipShape(Capsule())
                    Text("\(record.ttl)s")
                        .font(.caption).foregroundStyle(.secondary)
                        .frame(width: 60, alignment: .trailing)
                    Text(record.value)
                        .font(.system(.callout, design: .monospaced))
                        .textSelection(.enabled)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    CopyButton(text: record.value)
                }
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    private func runQuery() {
        let host = hostname.trimmingCharacters(in: .whitespaces)
        guard !host.isEmpty, !isQuerying else { return }
        let type = recordType
        let preset = DNSServerPreset.presets.first { $0.id == serverID } ?? DNSServerPreset.presets[0]
        isQuerying = true
        errorMessage = nil
        queryInfo = nil
        Task {
            do {
                let serverHost = preset.resolvedHost()
                let result = try await DNSLookupEngine.lookup(name: host, type: type, serverHost: serverHost)
                answers = result.message.answers
                authority = result.message.authority
                var info = String(format: "%.1f ms", result.elapsedMilliseconds)
                info += " · \(result.message.rcodeName)"
                info += " · \(result.serverHost)\(result.usedTCP ? " (TCP)" : "")"
                if result.queriedName != host { info += " · \(result.queriedName)" }
                queryInfo = info
            } catch {
                answers = []
                authority = []
                errorMessage = error.localizedDescription
            }
            hasQueried = true
            isQuerying = false
        }
    }
}

extension DNSLookupView {
    public static let descriptor = ToolDescriptor(
        id: "dns-lookup",
        name: "DNS Lookup",
        icon: "network",
        category: .developer,
        searchKeywords: ["dns", "dig", "nslookup", "lookup", "record", "mx", "txt", "cname", "ptr", "reverse", "域名", "解析", "查询", "反向"]
    )
}
