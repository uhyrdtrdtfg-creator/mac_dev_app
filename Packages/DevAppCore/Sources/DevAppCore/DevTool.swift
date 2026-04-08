import SwiftUI

public enum ToolCategory: String, CaseIterable, Identifiable, Sendable {
    case crypto
    case apiClient
    case conversion

    public var id: String { rawValue }

    public var displayName: LocalizedStringKey {
        switch self {
        case .crypto: "Crypto"
        case .apiClient: "API Client"
        case .conversion: "Conversion"
        }
    }

    public var icon: String {
        switch self {
        case .crypto: "lock.shield"
        case .apiClient: "network"
        case .conversion: "arrow.2.squarepath"
        }
    }
}

public protocol DevTool: Identifiable, View {
    var id: String { get }
    var name: LocalizedStringKey { get }
    var icon: String { get }
    var category: ToolCategory { get }
    var searchKeywords: [String] { get }
}
