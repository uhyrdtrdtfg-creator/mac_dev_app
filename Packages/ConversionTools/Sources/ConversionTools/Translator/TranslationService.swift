import Foundation
import NaturalLanguage

public struct DetectedLanguage: Sendable {
    public let code: String
    public let name: String
    public let confidence: Double
}

public enum TranslationError: Error, LocalizedError {
    case authFailed
    case requestFailed(String)
    case noResult

    public var errorDescription: String? {
        switch self {
        case .authFailed: "Failed to get translation auth token"
        case .requestFailed(let msg): "Translation failed: \(msg)"
        case .noResult: "No translation result returned"
        }
    }
}

public enum TranslationService {
    // MARK: - Language Detection (NLLanguageRecognizer, offline)

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

    // MARK: - Microsoft Free Translation (Edge Translator API, no key needed)

    nonisolated(unsafe) private static var cachedToken: (token: String, expiry: Date)?

    /// Fetch auth token from Microsoft Edge's translate endpoint
    private static func getAuthToken() async throws -> String {
        if let cached = cachedToken, cached.expiry > Date() {
            return cached.token
        }
        var request = URLRequest(url: URL(string: "https://edge.microsoft.com/translate/auth")!)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200,
              let token = String(data: data, encoding: .utf8), !token.isEmpty else {
            throw TranslationError.authFailed
        }
        // Token valid for ~10 minutes
        cachedToken = (token: token, expiry: Date().addingTimeInterval(540))
        return token
    }

    /// Translate text using Microsoft Translator API (free, no API key)
    public static func translate(_ text: String, from sourceCode: String, to targetCode: String) async throws -> String {
        let token = try await getAuthToken()

        // Map language codes: NLLanguage uses "zh-Hans" but MS API uses "zh-Hans" too (mostly compatible)
        let fromParam = sourceCode == "auto" ? "" : "&from=\(sourceCode)"
        let urlString = "https://api-edge.cognitive.microsofttranslator.com/translate?api-version=3.0&to=\(targetCode)\(fromParam)"
        guard let url = URL(string: urlString) else { throw TranslationError.requestFailed("Invalid URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")

        let body: [[String: String]] = [["Text": text]]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TranslationError.requestFailed(errorBody)
        }

        // Parse response: [{"translations": [{"text": "...", "to": "..."}]}]
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = json.first,
              let translations = first["translations"] as? [[String: Any]],
              let translated = translations.first?["text"] as? String else {
            throw TranslationError.noResult
        }

        return translated
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
        ("cs", "Czech"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("fi", "Finnish"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("hu", "Hungarian"),
        ("nb", "Norwegian"),
        ("ro", "Romanian"),
    ]

    public static func languageName(for code: String) -> String {
        let locale = Locale.current
        if let name = locale.localizedString(forLanguageCode: code), !name.isEmpty {
            return name
        }
        return supportedLanguages.first { $0.code == code }?.name ?? code
    }
}
