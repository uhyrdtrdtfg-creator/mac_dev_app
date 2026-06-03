import SwiftUI
import DevAppCore

@Observable
final class ToolRegistry {
    private(set) var descriptors: [ToolDescriptor] = []
    var selectedToolID: String?
    var searchText: String = ""

    private(set) var favorites: Set<String> = []
    private(set) var recents: [String] = []

    private let favoritesKey = "devtoolkit.favorites"
    private let recentsKey = "devtoolkit.recents"
    private let maxRecents = 6

    init() {
        favorites = Set(UserDefaults.standard.stringArray(forKey: favoritesKey) ?? [])
        recents = UserDefaults.standard.stringArray(forKey: recentsKey) ?? []
    }

    var filteredDescriptors: [ToolDescriptor] {
        guard !searchText.isEmpty else { return descriptors }
        let query = searchText.lowercased()
        return descriptors.filter { descriptor in
            descriptor.searchKeywords.contains { $0.lowercased().contains(query) }
        }
    }

    func descriptors(for category: ToolCategory) -> [ToolDescriptor] {
        filteredDescriptors.filter { $0.category == category }
    }

    func descriptor(for id: String) -> ToolDescriptor? {
        descriptors.first { $0.id == id }
    }

    var favoriteDescriptors: [ToolDescriptor] {
        descriptors.filter { favorites.contains($0.id) }
    }

    var recentDescriptors: [ToolDescriptor] {
        recents.compactMap { id in descriptors.first { $0.id == id } }
    }

    func register(_ descriptor: ToolDescriptor) {
        guard !descriptors.contains(where: { $0.id == descriptor.id }) else { return }
        descriptors.append(descriptor)
    }

    func registerAll(_ newDescriptors: [ToolDescriptor]) {
        for d in newDescriptors { register(d) }
    }

    // MARK: - Favorites & recents

    func isFavorite(_ id: String) -> Bool { favorites.contains(id) }

    func toggleFavorite(_ id: String) {
        if favorites.contains(id) { favorites.remove(id) } else { favorites.insert(id) }
        UserDefaults.standard.set(Array(favorites), forKey: favoritesKey)
    }

    func recordUsage(_ id: String) {
        recents.removeAll { $0 == id }
        recents.insert(id, at: 0)
        if recents.count > maxRecents { recents = Array(recents.prefix(maxRecents)) }
        UserDefaults.standard.set(recents, forKey: recentsKey)
    }
}
