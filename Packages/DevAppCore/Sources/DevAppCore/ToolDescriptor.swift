import SwiftUI

public struct ToolDescriptor: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let name: LocalizedStringKey
    public let icon: String
    public let category: ToolCategory
    public let searchKeywords: [String]

    public init(
        id: String,
        name: LocalizedStringKey,
        icon: String,
        category: ToolCategory,
        searchKeywords: [String]
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.searchKeywords = searchKeywords
    }

    public static func == (lhs: ToolDescriptor, rhs: ToolDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
