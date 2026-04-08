import SwiftUI
import DevAppCore

struct SidebarView: View {
    @Bindable var registry: ToolRegistry

    var body: some View {
        List(selection: $registry.selectedToolID) {
            ForEach(ToolCategory.allCases) { category in
                let tools = registry.descriptors(for: category)
                if !tools.isEmpty {
                    Section {
                        ForEach(tools) { descriptor in
                            HStack(spacing: 8) {
                                Image(systemName: descriptor.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(colorForCategory(category))
                                    .frame(width: 24, height: 24)
                                    .background(colorForCategory(category).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                Text(descriptor.name)
                                    .font(.body)
                            }
                            .tag(descriptor.id)
                        }
                    } header: {
                        Label {
                            Text(category.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .textCase(.uppercase)
                                .foregroundStyle(.secondary)
                        } icon: {
                            Image(systemName: category.icon)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .searchable(text: $registry.searchText, prompt: "Search tools...")
        .navigationTitle("DevToolkit")
    }

    private func colorForCategory(_ category: ToolCategory) -> Color {
        switch category {
        case .crypto: .blue
        case .apiClient: .green
        case .conversion: .orange
        }
    }
}
