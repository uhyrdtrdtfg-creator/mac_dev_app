import SwiftUI
import DevAppCore

public struct CronParserView: View {
    @State private var expression = "*/5 * * * *"
    @State private var description = ""
    @State private var nextRuns: [String] = []
    @State private var errorMessage: String?

    private let presets: [(String, String)] = [
        ("Every minute", "* * * * *"),
        ("Every 15 min", "*/15 * * * *"),
        ("Hourly", "0 * * * *"),
        ("Daily 9am", "0 9 * * *"),
        ("Weekdays 9am", "0 9 * * 1-5"),
        ("Monthly 1st", "0 0 1 * *")
    ]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cron Parser").font(.title2).fontWeight(.semibold)
                Text("Parse a 5-field cron expression into a description and upcoming run times")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            TextField("minute hour day-of-month month day-of-week", text: $expression)
                .font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                ForEach(["minute", "hour", "day", "month", "weekday"], id: \.self) { field in
                    Text(field).font(.caption2).foregroundStyle(.tertiary).frame(maxWidth: .infinity)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.0) { preset in
                        Button(preset.0) { expression = preset.1 }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.callout).foregroundStyle(.red)
            } else {
                Label(description, systemImage: "text.alignleft").font(.body).foregroundStyle(.primary)
                    .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !nextRuns.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next Runs").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    ForEach(Array(nextRuns.enumerated()), id: \.offset) { idx, run in
                        HStack {
                            Text("\(idx + 1).").font(.caption).foregroundStyle(.tertiary).frame(width: 24, alignment: .trailing)
                            Text(run).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Spacer()
                        }
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .onAppear { update() }
        .onChange(of: expression) { _, _ in update() }
    }

    private func update() {
        guard !expression.trimmingCharacters(in: .whitespaces).isEmpty else {
            description = ""; nextRuns = []; errorMessage = nil; return
        }
        do {
            let dates = try CronParser.nextDates(expression, after: Date(), count: 5)
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE yyyy-MM-dd HH:mm"
            nextRuns = dates.map { formatter.string(from: $0) }
            description = CronParser.describe(expression)
            errorMessage = nil
        } catch {
            description = ""; nextRuns = []
            errorMessage = error.localizedDescription
        }
    }
}

extension CronParserView {
    public static let descriptor = ToolDescriptor(
        id: "cron-parser",
        name: "Cron Parser",
        icon: "clock.badge.checkmark",
        category: .developer,
        searchKeywords: ["cron", "crontab", "schedule", "job", "next run", "定时", "计划任务"]
    )
}
