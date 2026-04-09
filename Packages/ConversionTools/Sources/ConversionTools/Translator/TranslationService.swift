import Foundation
import NaturalLanguage

public struct DetectedLanguage: Sendable {
    public let code: String
    public let name: String
    public let confidence: Double
}

public enum TranslationService {
    // MARK: - Language Detection

    public static func detectLanguage(_ text: String) -> DetectedLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let lang = recognizer.dominantLanguage else { return nil }
        let confidence = recognizer.languageHypotheses(withMaximum: 1)[lang] ?? 0
        return DetectedLanguage(
            code: lang.rawValue,
            name: Self.languageName(for: lang.rawValue),
            confidence: confidence
        )
    }

    public static func detectTopLanguages(_ text: String, max: Int = 5) -> [DetectedLanguage] {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.languageHypotheses(withMaximum: max).map { lang, conf in
            DetectedLanguage(code: lang.rawValue, name: Self.languageName(for: lang.rawValue), confidence: conf)
        }.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Supported Languages

    public static let supportedLanguages: [(code: String, name: String)] = [
        ("zh-Hans", "Chinese (Simplified)"),
        ("zh-Hant", "Chinese (Traditional)"),
        ("en", "English"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("fr", "French"),
        ("de", "German"),
        ("es", "Spanish"),
        ("pt", "Portuguese"),
        ("it", "Italian"),
        ("ru", "Russian"),
        ("ar", "Arabic"),
        ("hi", "Hindi"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
        ("id", "Indonesian"),
        ("ms", "Malay"),
        ("tr", "Turkish"),
        ("pl", "Polish"),
        ("nl", "Dutch"),
        ("uk", "Ukrainian"),
    ]

    public static func languageName(for code: String) -> String {
        let locale = Locale.current
        if let name = locale.localizedString(forLanguageCode: code), !name.isEmpty {
            return name
        }
        return supportedLanguages.first { $0.code == code }?.name ?? code
    }

    public static func localeLanguage(for code: String) -> Locale.Language {
        Locale.Language(identifier: code)
    }
}
