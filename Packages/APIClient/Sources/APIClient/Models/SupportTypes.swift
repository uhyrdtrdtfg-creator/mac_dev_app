import Foundation

public struct KeyValuePair: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(key: String = "", value: String = "", isEnabled: Bool = true) {
        self.key = key; self.value = value; self.isEnabled = isEnabled
    }
}

public enum HTTPMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case get = "GET"; case post = "POST"; case put = "PUT"; case patch = "PATCH"
    case delete = "DELETE"; case head = "HEAD"; case options = "OPTIONS"
    public var id: String { rawValue }
}

public enum RequestBody: Codable, Sendable {
    case json(String)
    case formData([KeyValuePair])
    case raw(String)
    case binary(Data)
}

public enum AuthType: Codable, Sendable {
    case bearerToken(String)
    case basicAuth(username: String, password: String)
    case apiKey(key: String, value: String, addTo: APIKeyLocation)
}

public enum APIKeyLocation: String, Codable, Sendable {
    case header; case queryParam
}
