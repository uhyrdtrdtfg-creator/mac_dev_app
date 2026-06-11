import Foundation

public enum OpenAPICodec {
    private static let methodOrder = ["get", "post", "put", "patch", "delete", "head", "options"]
    private static let maxSchemaDepth = 8

    // MARK: - Detection

    public static func isOpenAPIDocument(_ json: String) -> Bool {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return false }
        return obj["openapi"] is String || obj["swagger"] is String
    }

    // MARK: - Import

    public static func importDocument(_ json: String) -> [SavedRequestModel] {
        guard let data = json.data(using: .utf8),
              let doc = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              doc["openapi"] is String || doc["swagger"] is String,
              let paths = doc["paths"] as? [String: Any] else { return [] }

        let baseURL = baseURL(from: doc)
        let title = ((doc["info"] as? [String: Any])?["title"] as? String) ?? ""

        var results: [SavedRequestModel] = []
        for path in paths.keys.sorted() {
            guard let pathItem = paths[path] as? [String: Any] else { continue }
            let pathParams = parameterList(pathItem["parameters"], doc: doc)
            for method in methodOrder {
                guard let operation = pathItem[method] as? [String: Any] else { continue }
                results.append(request(
                    method: method.uppercased(), path: path, operation: operation,
                    pathParams: pathParams, baseURL: baseURL, title: title, doc: doc
                ))
            }
        }
        return results
    }

    private static func request(method: String, path: String, operation: [String: Any],
                                pathParams: [[String: Any]], baseURL: String,
                                title: String, doc: [String: Any]) -> SavedRequestModel {
        let name = (operation["operationId"] as? String)
            ?? (operation["summary"] as? String)
            ?? "\(method) \(path)"

        var url = baseURL + templated(path)
        var headers: [KeyValuePair] = []
        var queryItems: [(String, String)] = []
        for param in pathParams + parameterList(operation["parameters"], doc: doc) {
            guard let paramName = param["name"] as? String else { continue }
            switch param["in"] as? String {
            case "query": queryItems.append((paramName, parameterValue(param)))
            case "header": headers.append(KeyValuePair(key: paramName, value: parameterValue(param)))
            default: break
            }
        }
        if !queryItems.isEmpty {
            url += (url.contains("?") ? "&" : "?") + queryItems.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
        }

        let saved = SavedRequestModel(name: name, method: method, url: url)
        saved.headers = headers
        if let body = jsonBody(operation: operation, pathParams: pathParams, doc: doc) {
            saved.body = .json(body)
            saved.bodyType = "json"
        }
        let tag = (operation["tags"] as? [String])?.first
        let tagPath = [title.isEmpty ? nil : title, tag].compactMap { $0 }.joined(separator: "/")
        if !tagPath.isEmpty { saved.tagList = [tagPath] }
        return saved
    }

    private static func baseURL(from doc: [String: Any]) -> String {
        if let servers = doc["servers"] as? [[String: Any]],
           let url = servers.first?["url"] as? String {
            return templated(url.hasSuffix("/") ? String(url.dropLast()) : url)
        }
        // Swagger 2.0
        if let host = doc["host"] as? String {
            let scheme = (doc["schemes"] as? [String])?.first ?? "https"
            let basePath = doc["basePath"] as? String ?? ""
            return "\(scheme)://\(host)\(basePath == "/" ? "" : basePath)"
        }
        return ""
    }

    /// Converts OpenAPI `{param}` placeholders to the app's `{{param}}` variable syntax.
    private static func templated(_ path: String) -> String {
        path.replacingOccurrences(of: #"\{([A-Za-z0-9_.-]+)\}"#, with: "{{$1}}", options: .regularExpression)
    }

    private static func parameterList(_ raw: Any?, doc: [String: Any]) -> [[String: Any]] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { resolveRef($0, doc: doc) }
    }

    private static func parameterValue(_ param: [String: Any]) -> String {
        if let value = param["example"] { return stringify(value) }
        let schema = param["schema"] as? [String: Any] ?? [:]
        if let value = schema["example"] ?? schema["default"] { return stringify(value) }
        // Swagger 2.0 puts default/example directly on the parameter
        if let value = param["default"] { return stringify(value) }
        return ""
    }

    private static func stringify(_ value: Any) -> String {
        switch value {
        case let s as String: return s
        case let b as Bool: return b ? "true" : "false"
        case let n as NSNumber: return n.stringValue
        default: return ""
        }
    }

    // MARK: - Request body

    private static func jsonBody(operation: [String: Any], pathParams: [[String: Any]], doc: [String: Any]) -> String? {
        var schema: [String: Any]?
        if let requestBody = resolveRef(operation["requestBody"] as? [String: Any] ?? [:], doc: doc),
           let content = requestBody["content"] as? [String: Any],
           let mediaType = content["application/json"] as? [String: Any] {
            if let example = mediaType["example"], JSONSerialization.isValidJSONObject(example),
               let data = try? JSONSerialization.data(withJSONObject: example, options: [.prettyPrinted, .sortedKeys]) {
                return String(decoding: data, as: UTF8.self)
            }
            schema = mediaType["schema"] as? [String: Any]
        }
        // Swagger 2.0 body parameter
        if schema == nil {
            let bodyParam = (pathParams + parameterList(operation["parameters"], doc: doc))
                .first { ($0["in"] as? String) == "body" }
            schema = bodyParam?["schema"] as? [String: Any]
        }
        guard let schema else { return nil }
        let skeleton = skeletonValue(schema, doc: doc, depth: 0)
        if skeleton is NSNull { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: skeleton, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed]) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    private static func skeletonValue(_ schema: [String: Any], doc: [String: Any], depth: Int) -> Any {
        guard depth < maxSchemaDepth, let schema = resolveRef(schema, doc: doc) else { return NSNull() }
        if let example = schema["example"] { return example }
        if let def = schema["default"] { return def }
        if let allOf = schema["allOf"] as? [[String: Any]] {
            var merged: [String: Any] = [:]
            for sub in allOf {
                if let obj = skeletonValue(sub, doc: doc, depth: depth + 1) as? [String: Any] {
                    merged.merge(obj) { current, _ in current }
                }
            }
            return merged
        }
        let type = schema["type"] as? String
        if type == "object" || schema["properties"] != nil {
            guard let properties = schema["properties"] as? [String: Any] else { return [String: Any]() }
            var obj: [String: Any] = [:]
            for (key, value) in properties {
                guard let propSchema = value as? [String: Any] else { continue }
                obj[key] = skeletonValue(propSchema, doc: doc, depth: depth + 1)
            }
            return obj
        }
        switch type {
        case "array":
            guard let items = schema["items"] as? [String: Any] else { return [Any]() }
            let item = skeletonValue(items, doc: doc, depth: depth + 1)
            return item is NSNull ? [Any]() : [item]
        case "string":
            return (schema["enum"] as? [Any])?.first ?? ""
        case "integer", "number":
            return 0
        case "boolean":
            return false
        default:
            return NSNull()
        }
    }

    // MARK: - $ref resolution

    private static func resolveRef(_ obj: [String: Any], doc: [String: Any], depth: Int = 0) -> [String: Any]? {
        guard depth < maxSchemaDepth else { return nil }
        guard let ref = obj["$ref"] as? String else { return obj }
        guard ref.hasPrefix("#/") else { return nil }
        var node: Any = doc
        for component in ref.dropFirst(2).components(separatedBy: "/") {
            let key = component
                .replacingOccurrences(of: "~1", with: "/")
                .replacingOccurrences(of: "~0", with: "~")
            guard let dict = node as? [String: Any], let next = dict[key] else { return nil }
            node = next
        }
        guard let resolved = node as? [String: Any] else { return nil }
        return resolveRef(resolved, doc: doc, depth: depth + 1)
    }
}
