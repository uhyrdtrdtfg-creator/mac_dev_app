import Foundation
import SwiftData

@Model
public final class HTTPRequestModel {
    public var id: UUID = UUID()
    public var name: String = "New Request"
    public var method: String = "GET"
    public var url: String = ""
    public var headersJSON: Data?
    public var bodyJSON: Data?
    public var authJSON: Data?
    public var collection: HTTPCollectionModel?
    public var createdAt: Date = Date()
    public var lastExecutedAt: Date?

    public init(name: String = "New Request", method: String = "GET", url: String = "") {
        self.id = UUID(); self.name = name; self.method = method; self.url = url; self.createdAt = Date()
    }

    public var headers: [KeyValuePair] {
        get { guard let data = headersJSON else { return [] }; return (try? JSONDecoder().decode([KeyValuePair].self, from: data)) ?? [] }
        set { headersJSON = try? JSONEncoder().encode(newValue) }
    }

    public var body: RequestBody? {
        get { guard let data = bodyJSON else { return nil }; return try? JSONDecoder().decode(RequestBody.self, from: data) }
        set { bodyJSON = try? JSONEncoder().encode(newValue) }
    }

    public var auth: AuthType? {
        get { guard let data = authJSON else { return nil }; return try? JSONDecoder().decode(AuthType.self, from: data) }
        set { authJSON = try? JSONEncoder().encode(newValue) }
    }
}
