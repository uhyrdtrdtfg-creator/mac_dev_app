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

    public init(name: String = "New Collection") {
        self.id = UUID(); self.name = name; self.requests = []; self.createdAt = Date()
    }
}
