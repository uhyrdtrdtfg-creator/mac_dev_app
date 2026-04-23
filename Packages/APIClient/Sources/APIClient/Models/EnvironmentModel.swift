import Foundation
import SwiftData

/// Represents a named environment (e.g., Development, Staging, Production)
@Model
public final class EnvironmentModel {
    public var id: UUID = UUID()
    public var name: String = ""
    public var variablesJSON: Data?
    public var isActive: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(name: String, variables: [String: String] = [:]) {
        self.id = UUID()
        self.name = name
        self.variablesJSON = try? JSONEncoder().encode(variables)
        self.isActive = false
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var variables: [String: String] {
        get {
            guard let data = variablesJSON else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            variablesJSON = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}

/// Stores global variables that persist across all environments and requests
@Model
public final class GlobalVariablesModel {
    public var id: UUID = UUID()
    public var variablesJSON: Data?
    public var updatedAt: Date = Date()

    public init(variables: [String: String] = [:]) {
        self.id = UUID()
        self.variablesJSON = try? JSONEncoder().encode(variables)
        self.updatedAt = Date()
    }

    public var variables: [String: String] {
        get {
            guard let data = variablesJSON else { return [:] }
            return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
        }
        set {
            variablesJSON = try? JSONEncoder().encode(newValue)
            updatedAt = Date()
        }
    }
}
