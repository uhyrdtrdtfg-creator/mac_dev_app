import Foundation

public enum StringCase: String, CaseIterable, Identifiable, Sendable {
    case camelCase = "camelCase"
    case pascalCase = "PascalCase"
    case snakeCase = "snake_case"
    case kebabCase = "kebab-case"
    case upperCase = "UPPER CASE"
    case lowerCase = "lower case"
    case titleCase = "Title Case"

    public var id: String { rawValue }
}

public enum StringCaseConverter {
    public static func convert(_ input: String, to targetCase: StringCase) -> String {
        let words = splitIntoWords(input)
        switch targetCase {
        case .camelCase:
            guard let first = words.first else { return "" }
            return first.lowercased() + words.dropFirst().map { $0.capitalized }.joined()
        case .pascalCase:
            return words.map { $0.capitalized }.joined()
        case .snakeCase:
            return words.map { $0.lowercased() }.joined(separator: "_")
        case .kebabCase:
            return words.map { $0.lowercased() }.joined(separator: "-")
        case .upperCase:
            return words.map { $0.uppercased() }.joined(separator: " ")
        case .lowerCase:
            return words.map { $0.lowercased() }.joined(separator: " ")
        case .titleCase:
            return words.map { $0.capitalized }.joined(separator: " ")
        }
    }

    public static func convertAll(_ input: String) -> [StringCase: String] {
        var results: [StringCase: String] = [:]
        for c in StringCase.allCases { results[c] = convert(input, to: c) }
        return results
    }

    private static func splitIntoWords(_ input: String) -> [String] {
        // Handle snake_case and kebab-case
        var normalized = input.replacingOccurrences(of: "_", with: " ").replacingOccurrences(of: "-", with: " ")

        // Insert spaces before uppercase letters in camelCase/PascalCase
        var result = ""
        for (i, char) in normalized.enumerated() {
            if char.isUppercase && i > 0 {
                let prevIndex = normalized.index(normalized.startIndex, offsetBy: i - 1)
                if normalized[prevIndex].isLowercase {
                    result += " "
                }
            }
            result.append(char)
        }

        return result.split(separator: " ").map(String.init).filter { !$0.isEmpty }
    }
}
