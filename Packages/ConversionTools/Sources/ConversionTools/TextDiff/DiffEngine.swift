import Foundation

public enum DiffLineType: Sendable {
    case equal
    case added
    case removed
}

public struct DiffLine: Identifiable, Sendable {
    public let id = UUID()
    public let type: DiffLineType
    public let text: String
    public let leftLineNumber: Int?
    public let rightLineNumber: Int?
}

public enum DiffEngine {
    public static func diff(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")

        let lcs = computeLCS(oldLines, newLines)
        return buildDiffLines(oldLines: oldLines, newLines: newLines, lcs: lcs)
    }

    public struct DiffStats: Sendable {
        public let additions: Int
        public let deletions: Int
        public let unchanged: Int
    }

    public static func stats(from diffLines: [DiffLine]) -> DiffStats {
        var add = 0, del = 0, eq = 0
        for line in diffLines {
            switch line.type {
            case .added: add += 1
            case .removed: del += 1
            case .equal: eq += 1
            }
        }
        return DiffStats(additions: add, deletions: del, unchanged: eq)
    }

    // MARK: - LCS (Longest Common Subsequence)

    private static func computeLCS(_ a: [String], _ b: [String]) -> [[Int]] {
        let m = a.count
        let n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

        for i in 1...m {
            for j in 1...n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        return dp
    }

    private static func buildDiffLines(oldLines: [String], newLines: [String], lcs: [[Int]]) -> [DiffLine] {
        var i = oldLines.count
        var j = newLines.count
        var stack: [DiffLine] = []

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && oldLines[i - 1] == newLines[j - 1] {
                stack.append(DiffLine(type: .equal, text: oldLines[i - 1], leftLineNumber: i, rightLineNumber: j))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                stack.append(DiffLine(type: .added, text: newLines[j - 1], leftLineNumber: nil, rightLineNumber: j))
                j -= 1
            } else if i > 0 {
                stack.append(DiffLine(type: .removed, text: oldLines[i - 1], leftLineNumber: i, rightLineNumber: nil))
                i -= 1
            }
        }

        return stack.reversed()
    }
}
