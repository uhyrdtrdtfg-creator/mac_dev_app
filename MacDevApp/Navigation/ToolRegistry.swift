import SwiftUI
import DevAppCore

@Observable
final class ToolRegistry {
    private(set) var descriptors: [ToolDescriptor] = []
    var selectedToolID: String?
    var searchText: String = ""

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

    func register(_ descriptor: ToolDescriptor) {
        guard !descriptors.contains(where: { $0.id == descriptor.id }) else { return }
        descriptors.append(descriptor)
    }

    func registerAll(_ newDescriptors: [ToolDescriptor]) {
        for d in newDescriptors { register(d) }
    }
}
