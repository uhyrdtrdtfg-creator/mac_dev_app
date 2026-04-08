import Foundation

public enum LineSortMode: String, CaseIterable, Identifiable, Sendable {
    case ascending = "A → Z"
    case descending = "Z → A"
    case reverse = "Reverse Lines"
    case shuffle = "Shuffle"
    public var id: String { rawValue }
}

public enum LineSorter {
    public static func sort(_ input: String, mode: LineSortMode) -> String {
        var lines = input.components(separatedBy: "\n")
        switch mode {
        case .ascending: lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        case .descending: lines.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedDescending }
        case .reverse: lines.reverse()
        case .shuffle: lines.shuffle()
        }
        return lines.joined(separator: "\n")
    }

    public static func deduplicate(_ input: String) -> String {
        var seen = Set<String>()
        let lines = input.components(separatedBy: "\n")
        let unique = lines.filter { seen.insert($0).inserted }
        return unique.joined(separator: "\n")
    }

    public static func stats(_ input: String) -> (total: Int, unique: Int, duplicates: Int, empty: Int) {
        let lines = input.components(separatedBy: "\n")
        let total = lines.count
        let unique = Set(lines).count
        let empty = lines.filter { $0.trimmingCharacters(in: .whitespaces).isEmpty }.count
        return (total: total, unique: unique, duplicates: total - unique, empty: empty)
    }
}
