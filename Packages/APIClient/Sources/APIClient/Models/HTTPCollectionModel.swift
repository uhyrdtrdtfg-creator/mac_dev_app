import Foundation
import SwiftData

@Model
public final class HTTPCollectionModel {
    public var id: UUID = UUID()
    public var name: String = "New Collection"
    @Relationship(deleteRule: .cascade, inverse: \HTTPRequestModel.collection)
    public var requests: [HTTPRequestModel] = []
    public var parentCollection: HTTPCollectionModel?
    public var createdAt: Date = Date()

    /// Collection-scoped variables (pm.collectionVariables)
    public var variablesJSON: Data?

    public init(name: String = "New Collection") {
        self.id = UUID(); self.name = name; self.requests = []; self.createdAt = Date()
    }

    public var variables: [String: String] {
        get {
            guard let data = variablesJSON else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            variablesJSON = try? JSONEncoder().encode(newValue)
        }
    }
}
