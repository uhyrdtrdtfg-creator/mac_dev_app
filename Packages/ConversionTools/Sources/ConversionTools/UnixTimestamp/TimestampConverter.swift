import Foundation

public enum TimestampUnit: String, Sendable { case seconds; case milliseconds }

public struct TimestampResult: Sendable {
    public let iso8601: String
    public let rfc2822: String
    public let custom: String
    public let date: Date
}

public enum TimestampConverter {
    public static func detectUnit(_ input: String) -> TimestampUnit {
        input.trimmingCharacters(in: .whitespacesAndNewlines).count >= 13 ? .milliseconds : .seconds
    }

    public static func toDate(timestamp: Int64, isMilliseconds: Bool = false, timeZone: TimeZone = .current) -> TimestampResult {
        let seconds: TimeInterval = isMilliseconds ? Double(timestamp) / 1000.0 : Double(timestamp)
        let date = Date(timeIntervalSince1970: seconds)

        let iso = ISO8601DateFormatter(); iso.timeZone = timeZone
        let rfc = DateFormatter(); rfc.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"; rfc.timeZone = timeZone; rfc.locale = Locale(identifier: "en_US_POSIX")
        let custom = DateFormatter(); custom.dateFormat = "yyyy-MM-dd HH:mm:ss"; custom.timeZone = timeZone

        return TimestampResult(iso8601: iso.string(from: date), rfc2822: rfc.string(from: date), custom: custom.string(from: date), date: date)
    }

    public static func toTimestamp(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int, timeZone: TimeZone = .current) -> Int64? {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = timeZone
        var c = DateComponents(); c.year = year; c.month = month; c.day = day; c.hour = hour; c.minute = minute; c.second = second
        guard let date = cal.date(from: c) else { return nil }
        return Int64(date.timeIntervalSince1970)
    }

    public static func currentTimestamp() -> Int64 { Int64(Date().timeIntervalSince1970) }
    public static func currentTimestampMillis() -> Int64 { Int64(Date().timeIntervalSince1970 * 1000) }
}
