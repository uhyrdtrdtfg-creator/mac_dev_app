import Foundation
import SwiftData

@Model
public final class ChainStepModel {
    public var id: UUID
    public var order: Int
    public var savedRequestId: UUID
    public var variablesJSON: Data?
    @Relationship public var chain: ChainModel?

    public init(order: Int, savedRequestId: UUID) {
        self.id = UUID()
        self.order = order
        self.savedRequestId = savedRequestId
    }

    /// Per-step environment variables (injected before execution)
    public var variables: [KeyValuePair] {
        get {
            guard let d = variablesJSON else { return [] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: d)) ?? []
        }
        set { variablesJSON = try? JSONEncoder().encode(newValue) }
    }
}

@Model
public final class ChainModel {
    public var id: UUID
    public var name: String
    @Relationship(deleteRule: .cascade, inverse: \ChainStepModel.chain)
    public var steps: [ChainStepModel]
    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.steps = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var sortedSteps: [ChainStepModel] {
        steps.sorted { $0.order < $1.order }
    }
}
