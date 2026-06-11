import AppIntents
import ConversionTools
import Foundation

struct ConvertTimestampIntent: AppIntent {
    static let title: LocalizedStringResource = "Convert Timestamp"
    static let description = IntentDescription("Converts a Unix timestamp (seconds or milliseconds) to ISO 8601, or an ISO 8601 date to Unix seconds — auto-detected.")

    @Parameter(title: "Timestamp or ISO 8601 Date")
    var input: String

    static var parameterSummary: some ParameterSummary {
        Summary("Convert \(\.$input)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ToolIntentError.emptyInput }

        if let timestamp = Int64(trimmed) {
            let isMillis = TimestampConverter.detectUnit(trimmed) == .milliseconds
            let result = TimestampConverter.toDate(timestamp: timestamp, isMilliseconds: isMillis)
            return .result(value: result.iso8601, dialog: "\(trimmed) → \(result.iso8601)")
        }

        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = plain.date(from: trimmed) ?? fractional.date(from: trimmed) {
            let seconds = String(Int64(date.timeIntervalSince1970))
            return .result(value: seconds, dialog: "\(trimmed) → \(seconds)")
        }

        throw ToolIntentError.invalidInput("Expected a Unix timestamp (seconds or milliseconds) or an ISO 8601 date, got: \(trimmed)")
    }
}
