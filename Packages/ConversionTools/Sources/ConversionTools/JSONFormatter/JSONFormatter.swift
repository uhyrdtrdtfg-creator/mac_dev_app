import Foundation

public enum JSONIndent: String, CaseIterable, Identifiable, Sendable {
    case spaces2 = "2 Spaces"
    case spaces4 = "4 Spaces"
    case tab = "Tab"
    public var id: String { rawValue }
}

public struct JSONFormatResult: Sendable {
    public let output: String?
    public let error: String?
}

public struct JSONValidationResult: Sendable {
    public let isValid: Bool
    public let error: String?
}

public enum JSONFormatter {
    public static func format(_ input: String, indent: JSONIndent = .spaces2) -> JSONFormatResult {
        guard let data = input.data(using: .utf8) else { return JSONFormatResult(output: nil, error: "Invalid UTF-8 string") }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let formatted = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
            var result = String(data: formatted, encoding: .utf8) ?? ""
            switch indent {
            case .spaces2: break
            case .spaces4: result = result.replacingOccurrences(of: "  ", with: "    ")
            case .tab: result = result.replacingOccurrences(of: "  ", with: "\t")
            }
            return JSONFormatResult(output: result, error: nil)
        } catch { return JSONFormatResult(output: nil, error: error.localizedDescription) }
    }

    public static func minify(_ input: String) -> JSONFormatResult {
        guard let data = input.data(using: .utf8) else { return JSONFormatResult(output: nil, error: "Invalid UTF-8 string") }
        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let minified = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            return JSONFormatResult(output: String(data: minified, encoding: .utf8) ?? "", error: nil)
        } catch { return JSONFormatResult(output: nil, error: error.localizedDescription) }
    }

    public static func validate(_ input: String) -> JSONValidationResult {
        guard let data = input.data(using: .utf8) else { return JSONValidationResult(isValid: false, error: "Invalid UTF-8 string") }
        do { _ = try JSONSerialization.jsonObject(with: data); return JSONValidationResult(isValid: true, error: nil) }
        catch { return JSONValidationResult(isValid: false, error: error.localizedDescription) }
    }
}
