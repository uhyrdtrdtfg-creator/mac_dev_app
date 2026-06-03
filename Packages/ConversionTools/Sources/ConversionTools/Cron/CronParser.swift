import Foundation

public enum CronError: Error, LocalizedError {
    case wrongFieldCount
    case invalidField(String)

    public var errorDescription: String? {
        switch self {
        case .wrongFieldCount: "Cron must have 5 fields: minute hour day-of-month month day-of-week"
        case .invalidField(let f): "Invalid field: \(f)"
        }
    }
}

public struct CronExpression: Sendable {
    public let minutes: Set<Int>
    public let hours: Set<Int>
    public let daysOfMonth: Set<Int>
    public let months: Set<Int>
    public let daysOfWeek: Set<Int>
    public let domRestricted: Bool
    public let dowRestricted: Bool
}

public enum CronParser {
    public static func parse(_ expression: String) throws -> CronExpression {
        let fields = expression.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard fields.count == 5 else { throw CronError.wrongFieldCount }
        return CronExpression(
            minutes: try field(fields[0], min: 0, max: 59),
            hours: try field(fields[1], min: 0, max: 23),
            daysOfMonth: try field(fields[2], min: 1, max: 31),
            months: try field(fields[3], min: 1, max: 12),
            daysOfWeek: try field(fields[4], min: 0, max: 6).map { $0 == 7 ? 0 : $0 }.reduce(into: Set<Int>()) { $0.insert($1) },
            domRestricted: fields[2] != "*",
            dowRestricted: fields[4] != "*"
        )
    }

    /// Next `count` fire times strictly after `after`, using the given calendar (UTC recommended for tests).
    public static func nextDates(_ expression: String, after: Date, count: Int = 5, calendar: Calendar = .current) throws -> [Date] {
        let cron = try parse(expression)
        var results: [Date] = []
        // Start at the next whole minute.
        var candidate = calendar.date(bySetting: .second, value: 0, of: after) ?? after
        candidate = calendar.date(byAdding: .minute, value: 1, to: candidate) ?? after
        let limit = 366 * 24 * 60 * 4 // up to ~4 years of minutes
        var steps = 0
        while results.count < count && steps < limit {
            if matches(cron, date: candidate, calendar: calendar) {
                results.append(candidate)
            }
            candidate = calendar.date(byAdding: .minute, value: 1, to: candidate) ?? candidate
            steps += 1
        }
        return results
    }

    public static func matches(_ cron: CronExpression, date: Date, calendar: Calendar = .current) -> Bool {
        let c = calendar.dateComponents([.minute, .hour, .day, .month, .weekday], from: date)
        guard let minute = c.minute, let hour = c.hour, let day = c.day,
              let month = c.month, let weekday = c.weekday else { return false }
        let dow = weekday - 1 // Calendar weekday is 1=Sun...7=Sat

        guard cron.minutes.contains(minute), cron.hours.contains(hour), cron.months.contains(month) else { return false }

        // Vixie cron: if both DOM and DOW are restricted, match if EITHER matches.
        let domMatch = cron.daysOfMonth.contains(day)
        let dowMatch = cron.daysOfWeek.contains(dow)
        if cron.domRestricted && cron.dowRestricted {
            return domMatch || dowMatch
        }
        return domMatch && dowMatch
    }

    public static func describe(_ expression: String) -> String {
        guard let cron = try? parse(expression) else { return "Invalid cron expression" }
        let minute = listDesc(cron.minutes, total: 60)
        let hour = listDesc(cron.hours, total: 24)
        var parts: [String] = []

        if cron.minutes.count == 60 && cron.hours.count == 24 {
            parts.append("Every minute")
        } else if cron.minutes.count == 1, let m = cron.minutes.first, cron.hours.count == 1, let h = cron.hours.first {
            parts.append(String(format: "At %02d:%02d", h, m))
        } else {
            parts.append("At minute \(minute)" + (cron.hours.count == 24 ? "" : " past hour \(hour)"))
        }
        if cron.months.count != 12 { parts.append("in month \(listDesc(cron.months, total: 12))") }
        if cron.domRestricted { parts.append("on day-of-month \(listDesc(cron.daysOfMonth, total: 31))") }
        if cron.dowRestricted { parts.append("on \(weekdayDesc(cron.daysOfWeek))") }
        return parts.joined(separator: ", ")
    }

    // MARK: - Field parsing

    private static func field(_ value: String, min: Int, max: Int) throws -> Set<Int> {
        var result = Set<Int>()
        for part in value.split(separator: ",") {
            var step = 1
            var rangePart = String(part)
            if let slash = part.firstIndex(of: "/") {
                step = Int(part[part.index(after: slash)...]) ?? 1
                rangePart = String(part[..<slash])
            }
            let lo: Int, hi: Int
            if rangePart == "*" {
                lo = min; hi = max
            } else if let dash = rangePart.firstIndex(of: "-") {
                guard let a = Int(rangePart[..<dash]), let b = Int(rangePart[rangePart.index(after: dash)...]) else {
                    throw CronError.invalidField(value)
                }
                lo = a; hi = b
            } else {
                guard let v = Int(rangePart) else { throw CronError.invalidField(value) }
                lo = v; hi = v
            }
            guard lo >= min, hi <= max + (max == 6 ? 1 : 0), lo <= hi, step > 0 else { throw CronError.invalidField(value) }
            var i = lo
            while i <= hi { result.insert(i); i += step }
        }
        return result
    }

    private static func listDesc(_ set: Set<Int>, total: Int) -> String {
        if set.count == total { return "*" }
        return set.sorted().map(String.init).joined(separator: ",")
    }

    private static func weekdayDesc(_ set: Set<Int>) -> String {
        let names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        return set.sorted().compactMap { $0 >= 0 && $0 < 7 ? names[$0] : nil }.joined(separator: ", ")
    }
}
