import Foundation
import SwiftData

@Model
public final class SavedRequestModel {
    public var id: UUID
    public var name: String
    public var tags: String  // comma-separated tags, e.g. "auth,production,v2"
    public var method: String
    public var url: String
    public var headersJSON: Data?
    public var bodyJSON: Data?
    public var bodyType: String?
    public var preScript: String?
    public var postScript: String?
    public var rewriteScript: String?
    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String, method: String = "GET", url: String = "") {
        self.id = UUID()
        self.name = name
        self.method = method
        self.url = url
        self.tags = ""
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var tagList: [String] {
        get { tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty } }
        set { tags = newValue.joined(separator: ",") }
    }

    public var headers: [KeyValuePair] {
        get {
            guard let d = headersJSON else { return [] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: d)) ?? []
        }
        set { headersJSON = try? JSONEncoder().encode(newValue) }
    }

    public var body: RequestBody? {
        get {
            guard let d = bodyJSON else { return nil }
            return try? JSONDecoder().decode(RequestBody.self, from: d)
        }
        set { bodyJSON = try? JSONEncoder().encode(newValue) }
    }
}
