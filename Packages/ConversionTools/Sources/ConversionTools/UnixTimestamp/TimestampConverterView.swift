import SwiftUI
import DevAppCore

public struct TimestampConverterView: View {
    @State private var timestampInput = ""
    @State private var dateTimeInput = ""
    @State private var selectedTimeZone: TimeZone = .current
    @State private var nowTimestamp: Int64 = 0
    @State private var result: TimestampResult?
    @State private var timer: Timer?

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

            Picker("Time Zone", selection: $selectedTimeZone) {
                Text("UTC").tag(TimeZone.gmt)
                Text("Local (\(TimeZone.current.identifier))").tag(TimeZone.current)
            }.pickerStyle(.segmented).frame(width: 400)

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
        .onChange(of: selectedTimeZone) { _, _ in convertTimestamp(timestampInput) }
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
