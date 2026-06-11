import AppIntents
import ConversionTools

enum JSONIndentOption: String, AppEnum {
    case twoSpaces
    case fourSpaces
    case tab

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Indentation")
    static let caseDisplayRepresentations: [JSONIndentOption: DisplayRepresentation] = [
        .twoSpaces: "2 Spaces",
        .fourSpaces: "4 Spaces",
        .tab: "Tab",
    ]

    var indent: JSONIndent {
        switch self {
        case .twoSpaces: .spaces2
        case .fourSpaces: .spaces4
        case .tab: .tab
        }
    }
}

struct FormatJSONIntent: AppIntent {
    static let title: LocalizedStringResource = "Format JSON"
    static let description = IntentDescription("Pretty-prints a JSON string with the chosen indentation and sorted keys.")

    @Parameter(title: "JSON")
    var input: String

    @Parameter(title: "Indentation", default: .twoSpaces)
    var indent: JSONIndentOption

    static var parameterSummary: some ParameterSummary {
        Summary("Format \(\.$input) with \(\.$indent)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = JSONFormatter.format(input, indent: indent.indent)
        guard let output = result.output else {
            throw ToolIntentError.invalidInput("Invalid JSON: \(result.error ?? "unknown error")")
        }
        return .result(value: output)
    }
}

struct MinifyJSONIntent: AppIntent {
    static let title: LocalizedStringResource = "Minify JSON"
    static let description = IntentDescription("Removes all whitespace from a JSON string.")

    @Parameter(title: "JSON")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Minify \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let result = JSONFormatter.minify(input)
        guard let output = result.output else {
            throw ToolIntentError.invalidInput("Invalid JSON: \(result.error ?? "unknown error")")
        }
        return .result(value: output)
    }
}
