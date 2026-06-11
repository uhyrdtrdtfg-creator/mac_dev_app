import Foundation

/// Errors surfaced to Shortcuts when an intent gets unusable input.
enum ToolIntentError: Error, CustomLocalizedStringResourceConvertible {
    case emptyInput
    case invalidInput(String)
    case appNotReady

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .emptyInput: "The input text is empty."
        case .invalidInput(let message): "\(message)"
        case .appNotReady: "DevToolkit is still launching — try again in a moment."
        }
    }
}
