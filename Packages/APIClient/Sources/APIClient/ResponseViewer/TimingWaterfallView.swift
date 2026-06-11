import SwiftUI

struct TimingWaterfallView: View {
    let timing: TimingBreakdown

    private var phases: [(label: String, millis: Double, color: Color)] {
        var result: [(String, Double, Color)] = []
        if let v = timing.dnsMillis { result.append(("DNS", v, .purple)) }
        if let v = timing.tcpMillis { result.append(("TCP", v, .blue)) }
        if let v = timing.tlsMillis { result.append(("TLS", v, .teal)) }
        if let v = timing.ttfbMillis { result.append(("Wait (TTFB)", v, .orange)) }
        if let v = timing.downloadMillis { result.append(("Download", v, .green)) }
        return result
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timing").font(.headline)
            if phases.isEmpty {
                Text("No phase data (cached or reused connection)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                let maxMillis = max(phases.map(\.millis).max() ?? 1, 0.001)
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
                    ForEach(phases, id: \.label) { phase in
                        GridRow {
                            Text(phase.label).font(.caption).gridColumnAlignment(.trailing)
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(phase.color.gradient)
                                    .frame(width: max(2, geo.size.width * phase.millis / maxMillis))
                            }
                            .frame(width: 180, height: 12)
                            Text(formatMillis(phase.millis))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Divider()
            HStack {
                Text("Total").font(.caption.bold())
                Spacer()
                Text(formatMillis(timing.totalMillis)).font(.caption.monospacedDigit().bold())
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private func formatMillis(_ value: Double) -> String {
        value >= 1000 ? String(format: "%.2f s", value / 1000) : String(format: "%.1f ms", value)
    }
}
