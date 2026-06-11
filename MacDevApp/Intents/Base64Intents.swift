import AppIntents
import ConversionTools

struct Base64EncodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Encode Base64"
    static let description = IntentDescription("Encodes text as Base64.")

    @Parameter(title: "Text")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Base64-encode \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: Base64Codec.encode(input))
    }
}

struct Base64DecodeIntent: AppIntent {
    static let title: LocalizedStringResource = "Decode Base64"
    static let description = IntentDescription("Decodes a Base64 string (standard or URL-safe) back to text.")

    @Parameter(title: "Base64")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Base64-decode \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ToolIntentError.emptyInput }
        guard let decoded = Base64Codec.decode(trimmed) ?? Base64Codec.decode(trimmed, urlSafe: true) else {
            throw ToolIntentError.invalidInput("Not valid Base64, or the decoded bytes are not UTF-8 text.")
        }
        return .result(value: decoded)
    }
}
