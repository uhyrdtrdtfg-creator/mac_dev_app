import Foundation

public enum GraphQLEnvelopeError: Error, LocalizedError, Equatable {
    case variablesNotValidJSON(String)
    case variablesNotAnObject

    public var errorDescription: String? {
        switch self {
        case .variablesNotValidJSON(let detail): "Variables are not valid JSON: \(detail)"
        case .variablesNotAnObject: "Variables must be a JSON object (e.g. {\"id\": 1})"
        }
    }
}

/// Builds the standard GraphQL HTTP envelope: {"query": <query>, "variables": <parsed object>}.
/// The variables string is parsed as a JSON object; empty/whitespace omits the key entirely.
public enum GraphQLEnvelope {

    /// Envelope bytes, serialized with sorted keys so output is deterministic for a given input.
    public static func build(query: String, variables: String) throws -> Data {
        var envelope: [String: Any] = ["query": query]
        if let parsed = try parseVariables(variables) {
            envelope["variables"] = parsed
        }
        return try JSONSerialization.data(withJSONObject: envelope, options: [.sortedKeys])
    }

    public static func buildString(query: String, variables: String) throws -> String {
        String(decoding: try build(query: query, variables: variables), as: UTF8.self)
    }

    /// nil when the variables string is empty/whitespace; throws when it is not a JSON object.
    public static func parseVariables(_ text: String) throws -> [String: Any]? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let parsed: Any
        do {
            parsed = try JSONSerialization.jsonObject(with: Data(trimmed.utf8), options: [.fragmentsAllowed])
        } catch {
            throw GraphQLEnvelopeError.variablesNotValidJSON(error.localizedDescription)
        }
        guard let object = parsed as? [String: Any] else { throw GraphQLEnvelopeError.variablesNotAnObject }
        return object
    }

    /// Live UI hint: nil when the variables string is empty or a valid JSON object.
    public static func variablesValidationError(_ text: String) -> String? {
        do { _ = try parseVariables(text); return nil }
        catch let error as GraphQLEnvelopeError { return error.errorDescription }
        catch { return error.localizedDescription }
    }

    /// Inverse of build: splits envelope bytes back into (query, variables JSON string).
    /// Variables come back as a compact sorted-keys object string, or "" when absent.
    public static func decompose(_ data: Data) -> (query: String, variables: String)? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let query = object["query"] as? String else { return nil }
        var variables = ""
        if let vars = object["variables"] as? [String: Any],
           let varData = try? JSONSerialization.data(withJSONObject: vars, options: [.sortedKeys]) {
            variables = String(decoding: varData, as: UTF8.self)
        }
        return (query, variables)
    }
}
