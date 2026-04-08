import SwiftUI
import DevAppCore

struct SidebarView: View {
    @Bindable var registry: ToolRegistry

    var body: some View {
        List(selection: $registry.selectedToolID) {
            ForEach(ToolCategory.allCases) { category in
                let tools = registry.descriptors(for: category)
                if !tools.isEmpty {
                    Section(category.displayName) {
                        ForEach(tools) { descriptor in
                            Label(descriptor.name, systemImage: descriptor.icon)
                                .tag(descriptor.id)
                        }
                    }
                }
            }
        }
        .searchable(text: $registry.searchText, prompt: "Search tools...")
        .navigationTitle("Mac Dev App")
    }
}
