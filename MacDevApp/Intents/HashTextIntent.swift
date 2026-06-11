import AppIntents
import CryptoTools

enum HashAlgorithmOption: String, AppEnum {
    case md5
    case sha1
    case sha256
    case sha512

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Hash Algorithm")
    static let caseDisplayRepresentations: [HashAlgorithmOption: DisplayRepresentation] = [
        .md5: "MD5",
        .sha1: "SHA-1",
        .sha256: "SHA-256",
        .sha512: "SHA-512",
    ]

    var algorithm: HashAlgorithm {
        switch self {
        case .md5: .md5
        case .sha1: .sha1
        case .sha256: .sha256
        case .sha512: .sha512
        }
    }
}

struct HashTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Hash Text"
    static let description = IntentDescription("Computes the MD5, SHA-1, SHA-256, or SHA-512 hash of text as a lowercase hex string.")

    @Parameter(title: "Text")
    var input: String

    @Parameter(title: "Algorithm", default: .sha256)
    var algorithm: HashAlgorithmOption

    static var parameterSummary: some ParameterSummary {
        Summary("Hash \(\.$input) with \(\.$algorithm)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        guard !input.isEmpty else { throw ToolIntentError.emptyInput }
        return .result(value: HashGenerator.hash(input, algorithm: algorithm.algorithm))
    }
}
