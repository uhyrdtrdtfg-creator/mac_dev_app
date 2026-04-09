import SwiftUI
import DevAppCore

private struct TimeZoneOption: Identifiable, Hashable {
    let id: String
    let label: String
    let timeZone: TimeZone

    init(_ identifier: String, label: String? = nil) {
        self.id = identifier
        self.label = label ?? identifier
        self.timeZone = TimeZone(identifier: identifier) ?? .gmt
    }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: TimeZoneOption, rhs: TimeZoneOption) -> Bool { lhs.id == rhs.id }
}

private let commonTimeZones: [(String, [TimeZoneOption])] = [
    ("Common", [
        TimeZoneOption("GMT", label: "UTC / GMT"),
        TimeZoneOption(TimeZone.current.identifier, label: "Local (\(TimeZone.current.identifier))"),
    ]),
    ("Asia", [
        TimeZoneOption("Asia/Shanghai", label: "China (UTC+8)"),
        TimeZoneOption("Asia/Tokyo", label: "Japan (UTC+9)"),
        TimeZoneOption("Asia/Seoul", label: "Korea (UTC+9)"),
        TimeZoneOption("Asia/Singapore", label: "Singapore (UTC+8)"),
        TimeZoneOption("Asia/Hong_Kong", label: "Hong Kong (UTC+8)"),
        TimeZoneOption("Asia/Taipei", label: "Taipei (UTC+8)"),
        TimeZoneOption("Asia/Kolkata", label: "India (UTC+5:30)"),
        TimeZoneOption("Asia/Dubai", label: "Dubai (UTC+4)"),
    ]),
    ("Americas", [
        TimeZoneOption("America/New_York", label: "US Eastern"),
        TimeZoneOption("America/Chicago", label: "US Central"),
        TimeZoneOption("America/Denver", label: "US Mountain"),
        TimeZoneOption("America/Los_Angeles", label: "US Pacific"),
        TimeZoneOption("America/Sao_Paulo", label: "São Paulo"),
    ]),
    ("Europe", [
        TimeZoneOption("Europe/London", label: "London"),
        TimeZoneOption("Europe/Paris", label: "Central Europe"),
        TimeZoneOption("Europe/Moscow", label: "Moscow"),
    ]),
    ("Oceania", [
        TimeZoneOption("Australia/Sydney", label: "Sydney"),
        TimeZoneOption("Pacific/Auckland", label: "Auckland"),
    ]),
]

public struct TimestampConverterView: View {
    @State private var timestampInput = ""
    @State private var dateTimeInput = ""
    @State private var selectedTimeZoneId: String = TimeZone.current.identifier
    @State private var nowTimestamp: Int64 = 0
    @State private var result: TimestampResult?
    @State private var timer: Timer?

    private var selectedTimeZone: TimeZone {
        TimeZone(identifier: selectedTimeZoneId) ?? .current
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unix Timestamp Converter").font(.title2).fontWeight(.semibold)
                Text("Convert between Unix timestamps and human-readable dates").font(.subheadline).foregroundStyle(.secondary)
            }

            HStack {
                Text("Now:").font(.caption).foregroundStyle(.secondary)
                Text("\(nowTimestamp)").font(.system(.title3, design: .monospaced)).fontWeight(.medium).foregroundStyle(.blue)
                CopyButton(text: "\(nowTimestamp)")
            }.padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

            HStack(spacing: 8) {
                Text("Time Zone").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Picker("Time Zone", selection: $selectedTimeZoneId) {
                    ForEach(commonTimeZones, id: \.0) { group, zones in
                        Section(group) {
                            ForEach(zones) { zone in
                                Text(zone.label).tag(zone.id)
                            }
                        }
                    }
                }.frame(width: 250)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timestamp").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("Enter Unix timestamp...", text: $timestampInput)
                        .font(.system(.title3, design: .monospaced)).textFieldStyle(.plain).padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    if let result {
                        VStack(alignment: .leading, spacing: 6) {
                            formatRow("ISO 8601", result.iso8601)
                            formatRow("RFC 2822", result.rfc2822)
                            formatRow("Custom", result.custom)
                        }.padding(.top, 8)
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date & Time").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("yyyy-MM-dd HH:mm:ss", text: $dateTimeInput)
                        .font(.system(.title3, design: .monospaced)).textFieldStyle(.plain).padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: timestampInput) { _, newValue in convertTimestamp(newValue) }
        .onChange(of: dateTimeInput) { _, newValue in convertDateTime(newValue) }
        .onChange(of: selectedTimeZoneId) { _, _ in convertTimestamp(timestampInput) }
    }

    private func formatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
            Spacer()
            CopyButton(text: value)
        }
    }

    private func startTimer() {
        nowTimestamp = TimestampConverter.currentTimestamp()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in nowTimestamp = TimestampConverter.currentTimestamp() }
    }

    private func convertTimestamp(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(trimmed) else { result = nil; return }
        let unit = TimestampConverter.detectUnit(trimmed)
        result = TimestampConverter.toDate(timestamp: value, isMilliseconds: unit == .milliseconds, timeZone: selectedTimeZone)
        if let result { dateTimeInput = result.custom }
    }

    private func convertDateTime(_ input: String) {
        let fmt = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"; fmt.timeZone = selectedTimeZone
        guard let date = fmt.date(from: input) else { return }
        timestampInput = "\(Int64(date.timeIntervalSince1970))"
    }
}

extension TimestampConverterView {
    public static let descriptor = ToolDescriptor(id: "timestamp-converter", name: "Unix Timestamp", icon: "clock", category: .conversion, searchKeywords: ["unix", "timestamp", "time", "date", "epoch", "时间戳", "时间"])
}
