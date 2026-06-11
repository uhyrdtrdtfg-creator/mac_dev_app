import Foundation

public enum GraphQLIntrospectionError: Error, LocalizedError {
    case httpStatus(Int)
    case malformedResponse
    case graphQLErrors(String)

    public var errorDescription: String? {
        switch self {
        case .httpStatus(let code): "Introspection request failed with HTTP \(code)"
        case .malformedResponse: "Response did not contain a __schema object"
        case .graphQLErrors(let message): "GraphQL errors: \(message)"
        }
    }
}

public enum GraphQLIntrospection {

    /// Standard introspection query (types, fields, args, type refs nested 7 deep).
    public static let introspectionQuery = """
    query IntrospectionQuery {
      __schema {
        types {
          kind
          name
          fields(includeDeprecated: true) {
            name
            args { name type { ...TypeRef } }
            type { ...TypeRef }
          }
        }
      }
    }
    fragment TypeRef on __Type {
      kind name
      ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } }
    }
    """

    @MainActor private static var cache: [String: String] = [:]

    @MainActor
    public static func fetchSchemaSummary(url: String, headers: [KeyValuePair], auth: AuthType?, ignoreCache: Bool = false) async throws -> String {
        if !ignoreCache, let cached = cache[url] { return cached }
        let request = try HTTPClientService.buildURLRequest(
            method: .post, url: url, headers: headers, queryParams: [],
            body: .graphql(query: introspectionQuery, variables: ""), auth: auth
        )
        let response = try await HTTPClientService.send(request)
        guard (200..<300).contains(response.statusCode) else { throw GraphQLIntrospectionError.httpStatus(response.statusCode) }
        let summary = try summarizeSchema(response.body)
        cache[url] = summary
        return summary
    }

    /// Renders __schema types as plain text: "Name KIND" followed by one
    /// "  field(arg: Type): Type" line per field. Skips __ meta types.
    public static func summarizeSchema(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GraphQLIntrospectionError.malformedResponse
        }
        if let errors = root["errors"] as? [[String: Any]], !errors.isEmpty {
            let messages = errors.compactMap { $0["message"] as? String }.joined(separator: "; ")
            throw GraphQLIntrospectionError.graphQLErrors(messages.isEmpty ? "unknown error" : messages)
        }
        let schema = ((root["data"] as? [String: Any])?["__schema"] ?? root["__schema"]) as? [String: Any]
        guard let schema, let types = schema["types"] as? [[String: Any]] else {
            throw GraphQLIntrospectionError.malformedResponse
        }

        var blocks: [String] = []
        for type in types {
            guard let name = type["name"] as? String, !name.hasPrefix("__") else { continue }
            let kind = type["kind"] as? String ?? "TYPE"
            var lines = ["\(name) \(kind)"]
            for field in type["fields"] as? [[String: Any]] ?? [] {
                guard let fieldName = field["name"] as? String else { continue }
                let args = (field["args"] as? [[String: Any]] ?? []).compactMap { arg -> String? in
                    guard let argName = arg["name"] as? String else { return nil }
                    return "\(argName): \(typeName(arg["type"]))"
                }
                let argList = args.isEmpty ? "" : "(\(args.joined(separator: ", ")))"
                lines.append("  \(fieldName)\(argList): \(typeName(field["type"]))")
            }
            blocks.append(lines.joined(separator: "\n"))
        }
        return blocks.isEmpty ? "No types found in schema." : blocks.joined(separator: "\n\n")
    }

    private static func typeName(_ any: Any?) -> String {
        guard let type = any as? [String: Any] else { return "Unknown" }
        switch type["kind"] as? String {
        case "NON_NULL": return typeName(type["ofType"]) + "!"
        case "LIST": return "[" + typeName(type["ofType"]) + "]"
        default: return type["name"] as? String ?? "Unknown"
        }
    }
}
