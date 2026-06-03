import Foundation

public struct RegexCaptureGroup: Identifiable, Sendable {
    public let id = UUID()
    public let index: Int
    public let name: String?
    public let value: String
}

public struct RegexMatch: Identifiable, Sendable {
    public let id = UUID()
    public let range: Range<Int>      // UTF-16 offsets into the input
    public let value: String
    public let groups: [RegexCaptureGroup]
}

public struct RegexOptions: Sendable {
    public var caseInsensitive = false
    public var dotMatchesNewlines = false
    public var anchorsMatchLines = false
    public var allowComments = false

    public init() {}

    var nsOptions: NSRegularExpression.Options {
        var o: NSRegularExpression.Options = []
        if caseInsensitive { o.insert(.caseInsensitive) }
        if dotMatchesNewlines { o.insert(.dotMatchesLineSeparators) }
        if anchorsMatchLines { o.insert(.anchorsMatchLines) }
        if allowComments { o.insert(.allowCommentsAndWhitespace) }
        return o
    }
}

public enum RegexTester {
    public static func matches(pattern: String, in text: String, options: RegexOptions = RegexOptions()) -> Result<[RegexMatch], Error> {
        guard !pattern.isEmpty else { return .success([]) }
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options.nsOptions)
            let ns = text as NSString
            let full = NSRange(location: 0, length: ns.length)
            let results = regex.matches(in: text, options: [], range: full)
            let names = captureGroupNames(in: pattern)
            let mapped = results.map { result -> RegexMatch in
                var groups: [RegexCaptureGroup] = []
                for i in 1..<result.numberOfRanges {
                    let r = result.range(at: i)
                    let value = r.location == NSNotFound ? "" : ns.substring(with: r)
                    groups.append(RegexCaptureGroup(index: i, name: names[i], value: value))
                }
                let mr = result.range
                return RegexMatch(range: mr.location..<(mr.location + mr.length), value: ns.substring(with: mr), groups: groups)
            }
            return .success(mapped)
        } catch {
            return .failure(error)
        }
    }

    public static func replace(pattern: String, in text: String, template: String, options: RegexOptions = RegexOptions()) -> Result<String, Error> {
        guard !pattern.isEmpty else { return .success(text) }
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: options.nsOptions)
            let ns = text as NSString
            let full = NSRange(location: 0, length: ns.length)
            return .success(regex.stringByReplacingMatches(in: text, options: [], range: full, withTemplate: template))
        } catch {
            return .failure(error)
        }
    }

    private static func captureGroupNames(in pattern: String) -> [Int: String] {
        // Detect (?<name>...) named groups, mapping them to sequential group indices.
        var names: [Int: String] = [:]
        guard let detector = try? NSRegularExpression(pattern: "\\((?:\\?P?<([a-zA-Z_][a-zA-Z0-9_]*)>)?", options: []) else { return names }
        let ns = pattern as NSString
        var groupIndex = 0
        for m in detector.matches(in: pattern, range: NSRange(location: 0, length: ns.length)) {
            // Skip non-capturing groups (?: ... )
            let start = m.range.location
            if start + 2 < ns.length, ns.substring(with: NSRange(location: start, length: 3)) == "(?:" { continue }
            groupIndex += 1
            let nameRange = m.range(at: 1)
            if nameRange.location != NSNotFound {
                names[groupIndex] = ns.substring(with: nameRange)
            }
        }
        return names
    }
}
