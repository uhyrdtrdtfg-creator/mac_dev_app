import AppIntents
import ConversionTools

struct URLEncodeIntent: AppIntent {
    static let title: LocalizedStringResource = "URL Encode"
    static let description = IntentDescription("Percent-encodes text for safe use in a URL (RFC 3986).")

    @Parameter(title: "Text")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("URL-encode \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: URLCodec.encode(input))
    }
}

struct URLDecodeIntent: AppIntent {
    static let title: LocalizedStringResource = "URL Decode"
    static let description = IntentDescription("Decodes percent-encoded text (and form-encoded + as space).")

    @Parameter(title: "Text")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("URL-decode \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        .result(value: URLCodec.decode(input))
    }
}
