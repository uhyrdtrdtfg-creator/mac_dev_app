import Foundation
import SwiftData

@Model
public final class OpenTabModel {
    public var id: UUID = UUID()
    public var sortIndex: Int = 0
    public var isActive: Bool = false
    public var isDirty: Bool = false
    public var displayName: String = ""
    public var linkedSavedRequestID: UUID?

    public var method: String = "GET"
    public var url: String = ""
    public var queryParamsJSON: Data?
    public var headersJSON: Data?
    public var bodyType: String = "None"
    public var jsonBody: String = ""
    public var formDataJSON: Data?
    public var rawBody: String = ""
    public var authMethod: String = "None"
    public var bearerToken: String = ""
    public var basicUsername: String = ""
    public var basicPassword: String = ""
    public var apiKeyName: String = ""
    public var apiKeyValue: String = ""
    public var apiKeyLocation: String = "header"
    public var preScript: String = ""
    public var postScript: String = ""
    public var rewriteScript: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    // Last response snapshot (per-tab)
    public var lastResponseStatusCode: Int?
    public var lastResponseBody: Data?
    public var lastResponseHeadersJSON: Data?
    public var lastResponseDuration: Double?
    public var lastResponseBodySize: Int?
    public var lastResponseCookiesJSON: Data?
    public var lastErrorMessage: String?
    public var lastCurlCommand: String?
    public var lastResponseAt: Date?

    public init() {
        self.id = UUID()
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var queryParams: [KeyValuePair] {
        get {
            guard let d = queryParamsJSON else { return [KeyValuePair()] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: d)) ?? [KeyValuePair()]
        }
        set { queryParamsJSON = try? JSONEncoder().encode(newValue) }
    }

    public var headers: [KeyValuePair] {
        get {
            guard let d = headersJSON else { return [KeyValuePair()] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: d)) ?? [KeyValuePair()]
        }
        set { headersJSON = try? JSONEncoder().encode(newValue) }
    }

    public var formDataPairs: [KeyValuePair] {
        get {
            guard let d = formDataJSON else { return [KeyValuePair()] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: d)) ?? [KeyValuePair()]
        }
        set { formDataJSON = try? JSONEncoder().encode(newValue) }
    }
}
