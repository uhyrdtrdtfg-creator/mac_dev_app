import Foundation

public struct PlistConvertResult: Sendable {
    public let output: String?
    public let error: String?
}

public struct PlistBinaryResult: Sendable {
    public let data: Data?
    public let base64: String?
    public let error: String?
}

public enum PlistInputKind: Sendable, Equatable {
    case xmlPlist
    case json
    case base64Binary
    case unknown
}

/// Converts between XML/binary property lists and JSON.
///
/// JSON type mapping (plists have richer types than JSON):
/// - `<date>` -> ISO8601 string (e.g. "2024-01-15T10:30:00Z"); JSON strings in strict
///   ISO8601 date-time format convert back to `<date>`.
/// - `<data>` -> base64 string (one-way; base64 strings are not auto-converted back).
/// - `<integer>`, `<real>`, `<true/>`/`<false/>` map to JSON numbers/booleans and back.
/// - JSON `null` is rejected: property lists have no null type.
public enum PlistConverter {
    // MARK: - Detection

    public static func detect(_ input: String) -> PlistInputKind {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        if trimmed.hasPrefix("<?xml") || trimmed.hasPrefix("<!DOCTYPE plist") || trimmed.hasPrefix("<plist") { return .xmlPlist }
        if let data = Data(base64Encoded: trimmed, options: .ignoreUnknownCharacters), data.count > 8, data.prefix(6) == Data("bplist".utf8) { return .base64Binary }
        if let first = trimmed.first, first == "{" || first == "[" || first == "\"" { return .json }
        return .unknown
    }

    // MARK: - Plist -> JSON

    /// Accepts XML plist text or base64 of a binary plist.
    public static func plistToJSON(_ input: String) -> PlistConvertResult {
        switch resolvePlistData(input) {
        case .success(let data): return plistDataToJSON(data)
        case .failure(let message): return PlistConvertResult(output: nil, error: message)
        }
    }

    public static func plistDataToJSON(_ data: Data) -> PlistConvertResult {
        do {
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            let jsonObject = plistToJSONObject(object)
            // JSONSerialization raises an uncatchable ObjC exception for non-finite numbers
            // (e.g. <real>nan</real> or <real>+infinity</real>, which are valid plist values),
            // so validate first. Wrap in an array: isValidJSONObject rejects top-level fragments.
            guard JSONSerialization.isValidJSONObject([jsonObject]) else {
                return PlistConvertResult(output: nil, error: "Plist contains a value that cannot be represented in JSON (e.g. a non-finite <real> such as nan or infinity).")
            }
            let jsonData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys, .fragmentsAllowed])
            return PlistConvertResult(output: String(data: jsonData, encoding: .utf8) ?? "", error: nil)
        } catch { return PlistConvertResult(output: nil, error: friendlyError(error)) }
    }

    // MARK: - JSON -> XML plist

    public static func jsonToXML(_ json: String) -> PlistConvertResult {
        guard let data = json.data(using: .utf8) else { return PlistConvertResult(output: nil, error: "Invalid UTF-8 string") }
        do {
            let object = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
            let plistObject = try jsonToPlistObject(object, path: "$")
            let plistData = try PropertyListSerialization.data(fromPropertyList: plistObject, format: .xml, options: 0)
            return PlistConvertResult(output: String(data: plistData, encoding: .utf8) ?? "", error: nil)
        } catch let error as PlistMappingError {
            return PlistConvertResult(output: nil, error: error.message)
        } catch { return PlistConvertResult(output: nil, error: friendlyError(error)) }
    }

    // MARK: - Binary plist -> XML

    /// Raw file Data: binary or XML plist.
    public static func dataToXML(_ data: Data) -> PlistConvertResult {
        do {
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            let xml = try PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0)
            return PlistConvertResult(output: String(data: xml, encoding: .utf8) ?? "", error: nil)
        } catch { return PlistConvertResult(output: nil, error: friendlyError(error)) }
    }

    public static func base64BinaryToXML(_ base64: String) -> PlistConvertResult {
        guard let data = Data(base64Encoded: base64.trimmingCharacters(in: .whitespacesAndNewlines), options: .ignoreUnknownCharacters) else {
            return PlistConvertResult(output: nil, error: "Input is not valid base64")
        }
        return dataToXML(data)
    }

    // MARK: - XML plist -> binary

    /// Accepts XML plist text or base64 of a binary plist; returns binary Data + its base64.
    public static func xmlToBinary(_ input: String) -> PlistBinaryResult {
        let data: Data
        switch resolvePlistData(input) {
        case .success(let d): data = d
        case .failure(let message): return PlistBinaryResult(data: nil, base64: nil, error: message)
        }
        do {
            let object = try PropertyListSerialization.propertyList(from: data, format: nil)
            let binary = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
            return PlistBinaryResult(data: binary, base64: binary.base64EncodedString(), error: nil)
        } catch { return PlistBinaryResult(data: nil, base64: nil, error: friendlyError(error)) }
    }

    // MARK: - Format / validate

    /// Parses an XML plist (or base64 binary plist) and re-serializes it as canonical XML.
    public static func formatXML(_ input: String) -> PlistConvertResult {
        switch resolvePlistData(input) {
        case .success(let data): return dataToXML(data)
        case .failure(let message): return PlistConvertResult(output: nil, error: message)
        }
    }

    // MARK: - Helpers

    private enum ResolveResult {
        case success(Data)
        case failure(String)
    }

    private static func resolvePlistData(_ input: String) -> ResolveResult {
        if case .base64Binary = detect(input),
           let data = Data(base64Encoded: input.trimmingCharacters(in: .whitespacesAndNewlines), options: .ignoreUnknownCharacters) {
            return .success(data)
        }
        guard let data = input.data(using: .utf8) else { return .failure("Invalid UTF-8 string") }
        return .success(data)
    }

    private static func plistToJSONObject(_ value: Any) -> Any {
        switch value {
        case let date as Date: return date.formatted(.iso8601)
        case let data as Data: return data.base64EncodedString()
        case let dict as [String: Any]: return dict.mapValues { plistToJSONObject($0) }
        case let array as [Any]: return array.map { plistToJSONObject($0) }
        default: return value
        }
    }

    private struct PlistMappingError: Error { let message: String }

    private static func jsonToPlistObject(_ value: Any, path: String) throws -> Any {
        switch value {
        case is NSNull:
            throw PlistMappingError(message: "JSON null at \(path) — property lists have no null type. Remove the key or use an empty string instead.")
        case let dict as [String: Any]:
            var result = [String: Any](minimumCapacity: dict.count)
            for (key, item) in dict { result[key] = try jsonToPlistObject(item, path: "\(path).\(key)") }
            return result
        case let array as [Any]:
            return try array.enumerated().map { try jsonToPlistObject($0.element, path: "\(path)[\($0.offset)]") }
        case let string as String:
            if let date = parseISO8601(string) { return date }
            return string
        default:
            return value
        }
    }

    private static func parseISO8601(_ string: String) -> Date? {
        guard string.wholeMatch(of: #/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})/#) != nil else { return nil }
        if let date = try? Date(string, strategy: Date.ISO8601FormatStyle()) { return date }
        return try? Date(string, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    private static func friendlyError(_ error: Error) -> String {
        let ns = error as NSError
        if let debug = ns.userInfo[NSDebugDescriptionErrorKey] as? String, !debug.isEmpty { return debug }
        return ns.localizedDescription
    }
}
