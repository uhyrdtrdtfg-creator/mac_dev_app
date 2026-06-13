import SwiftUI
import DevAppCore

public struct PingView: View {
    private struct LogRow: Identifiable {
        let id = UUID()
        enum Kind {
            case info(String)
            case reply(PingReply)
            case timeout(Int)
            case failure(String)
        }
        let kind: Kind
    }

    private static let countPresets: [(label: String, value: Int)] = [
        ("5", 5), ("10", 10), ("25", 25), ("∞", 0)
    ]

    @State private var host = "8.8.8.8"
    @State private var count = 5
    @State private var rows: [LogRow] = []
    @State private var isPinging = false
    @State private var pingTask: Task<Void, Never>?
    @State private var finished = false

    // Live aggregates — kept incrementally so continuous pings stay O(1)
    // regardless of how many rows we display.
    @State private var sent = 0
    @State private var received = 0
    @State private var lastRTT: Double?
    @State private var minRTT = Double.greatestFiniteMagnitude
    @State private var maxRTT = 0.0
    @State private var sumRTT = 0.0
    @State private var sumSqRTT = 0.0

    private let maxRows = 500

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            controls
            statsBar
            resultsList
            Spacer(minLength: 0)
        }
        .padding()
        .onDisappear { pingTask?.cancel() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Ping").font(.title2).fontWeight(.semibold)
            Text("Send ICMP echo requests and measure round-trip latency and packet loss")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            TextField("Hostname or IP address", text: $host)
                .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { toggle() }
                .disabled(isPinging)

            Picker("", selection: $count) {
                ForEach(Self.countPresets, id: \.value) { preset in
                    Text(preset.label).tag(preset.value)
                }
            }
            .labelsHidden().fixedSize().disabled(isPinging)
            .help("Number of packets to send (∞ = continuous until stopped)")

            Button {
                toggle()
            } label: {
                Text(isPinging ? "Stop" : "Ping").frame(width: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(isPinging ? .red : .accentColor)
            .disabled(host.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var statsBar: some View {
        if sent > 0 || isPinging {
            HStack(spacing: 14) {
                stat("Sent", "\(sent)")
                stat("Recv", "\(received)")
                stat("Loss", String(format: "%.0f%%", lossPercent), tint: lossPercent > 0 ? .orange : .primary)
                Divider().frame(height: 26)
                stat("Last", format(lastRTT))
                stat("Avg", format(avgRTT))
                stat("Min", format(minRTT == .greatestFiniteMagnitude ? nil : minRTT))
                stat("Max", format(received > 0 ? maxRTT : nil))
                if let sd = stddevRTT {
                    stat("StdDev", String(format: "%.1f ms", sd))
                }
                Spacer()
                if isPinging {
                    ProgressView().controlSize(.small)
                } else if finished {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(rows) { row in
                        rowView(row).id(row.id)
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.fill.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onChange(of: rows.count) {
                if let last = rows.last { proxy.scrollTo(last.id, anchor: .bottom) }
            }
            .overlay {
                if rows.isEmpty {
                    Text("Enter a host and press Ping")
                        .font(.callout).foregroundStyle(.tertiary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: LogRow) -> some View {
        switch row.kind {
        case .info(let text):
            Text(text)
                .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4)
        case .reply(let reply):
            HStack(spacing: 10) {
                Text("seq \(reply.sequence)")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Text("from \(reply.host)")
                    .font(.system(.caption, design: .monospaced))
                    .frame(minWidth: 130, alignment: .leading).textSelection(.enabled)
                Text(reply.ttl.map { "ttl \($0)" } ?? "")
                    .font(.caption2).foregroundStyle(.secondary)
                    .frame(width: 52, alignment: .leading)
                latencyBar(reply.timeMilliseconds)
                Text(String(format: "%.2f ms", reply.timeMilliseconds))
                    .font(.system(.caption, design: .monospaced)).monospacedDigit()
                    .frame(width: 74, alignment: .trailing)
            }
            .padding(.horizontal, 4).padding(.vertical, 1)
        case .timeout(let seq):
            HStack(spacing: 10) {
                Text("seq \(seq)")
                    .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    .frame(width: 60, alignment: .leading)
                Label("Request timeout", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption).foregroundStyle(.orange)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 1)
        case .failure(let message):
            Label(message, systemImage: "xmark.octagon.fill")
                .font(.caption).foregroundStyle(.red).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 4).padding(.vertical, 1)
        }
    }

    private func latencyBar(_ ms: Double) -> some View {
        let scale = Swift.max(maxRTT, 20)
        let fraction = Swift.min(1, ms / scale)
        return ZStack(alignment: .leading) {
            Capsule().fill(.quaternary).frame(width: 120, height: 6)
            Capsule().fill(latencyColor(ms)).frame(width: Swift.max(3, 120 * fraction), height: 6)
        }
        .frame(width: 120)
        .accessibilityHidden(true)
    }

    private func latencyColor(_ ms: Double) -> Color {
        switch ms {
        case ..<50: .green
        case ..<150: .yellow
        default: .orange
        }
    }

    private func stat(_ label: String, _ value: String, tint: Color = .primary) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label).font(.caption2).foregroundStyle(.secondary).textCase(.uppercase)
            Text(value).font(.system(.callout, design: .monospaced)).foregroundStyle(tint).monospacedDigit()
        }
        .frame(minWidth: 40, alignment: .leading)
    }

    // MARK: - Derived stats

    private var lossPercent: Double { sent > 0 ? Double(sent - received) / Double(sent) * 100 : 0 }
    private var avgRTT: Double? { received > 0 ? sumRTT / Double(received) : nil }
    private var stddevRTT: Double? {
        guard received > 0 else { return nil }
        let mean = sumRTT / Double(received)
        let variance = Swift.max(0, sumSqRTT / Double(received) - mean * mean)
        return variance.squareRoot()
    }

    private func format(_ value: Double?) -> String {
        value.map { String(format: "%.1f ms", $0) } ?? "—"
    }

    // MARK: - Run control

    private func toggle() {
        if isPinging { stop() } else { start() }
    }

    private func start() {
        let target = host.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty, !isPinging else { return }
        reset()
        isPinging = true
        let selected = count
        pingTask = Task {
            let stream = PingEngine.ping(host: target, count: selected == 0 ? nil : selected)
            for await event in stream {
                apply(event)
            }
            isPinging = false
            finished = true
            pingTask = nil
        }
    }

    private func stop() {
        pingTask?.cancel()
        pingTask = nil
        isPinging = false
        finished = true
    }

    private func reset() {
        rows = []
        sent = 0
        received = 0
        lastRTT = nil
        minRTT = .greatestFiniteMagnitude
        maxRTT = 0
        sumRTT = 0
        sumSqRTT = 0
        finished = false
    }

    private func apply(_ event: PingEvent) {
        switch event {
        case .start(let banner):
            append(LogRow(kind: .info(banner)))
        case .reply(let reply):
            sent += 1
            received += 1
            lastRTT = reply.timeMilliseconds
            minRTT = Swift.min(minRTT, reply.timeMilliseconds)
            maxRTT = Swift.max(maxRTT, reply.timeMilliseconds)
            sumRTT += reply.timeMilliseconds
            sumSqRTT += reply.timeMilliseconds * reply.timeMilliseconds
            append(LogRow(kind: .reply(reply)))
        case .timeout(let seq):
            sent += 1
            append(LogRow(kind: .timeout(seq)))
        case .failure(let message):
            append(LogRow(kind: .failure(message)))
        case .summary:
            // Live aggregates already mirror the run; nothing to add.
            break
        }
    }

    private func append(_ row: LogRow) {
        rows.append(row)
        if rows.count > maxRows {
            rows.removeFirst(rows.count - maxRows)
        }
    }
}

extension PingView {
    public static let descriptor = ToolDescriptor(
        id: "ping",
        name: "Ping",
        icon: "antenna.radiowaves.left.and.right",
        category: .developer,
        searchKeywords: [
            "ping", "icmp", "latency", "rtt", "round-trip", "packet loss", "reachability",
            "echo", "ttl", "network", "延迟", "丢包", "网络", "连通性", "时延", "探测"
        ]
    )
}
