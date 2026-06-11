import AppIntents
import ConversionTools

struct GenerateUUIDIntent: AppIntent {
    static let title: LocalizedStringResource = "Generate UUID"
    static let description = IntentDescription("Generates one or more random version-4 UUIDs, one per line.")

    @Parameter(title: "Count", default: 1, inclusiveRange: (1, 100))
    var count: Int

    @Parameter(title: "Uppercase", default: true)
    var uppercase: Bool

    static var parameterSummary: some ParameterSummary {
        Summary("Generate \(\.$count) UUIDs") {
            \.$uppercase
        }
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let uuids = UUIDGenerator.generateBatch(count).map { uppercase ? $0 : $0.lowercased() }
        let value = uuids.joined(separator: "\n")
        let dialog: IntentDialog = count == 1 ? "\(value)" : "Generated \(count) UUIDs."
        return .result(value: value, dialog: dialog)
    }
}
