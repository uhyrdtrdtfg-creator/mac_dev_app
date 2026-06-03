import SwiftUI
import DevAppCore

struct SidebarView: View {
    @Bindable var registry: ToolRegistry

    var body: some View {
        List(selection: $registry.selectedToolID) {
            // Favorites & Recent (hidden while searching)
            if registry.searchText.isEmpty {
                if !registry.favoriteDescriptors.isEmpty {
                    Section {
                        ForEach(registry.favoriteDescriptors) { descriptor in
                            row(descriptor, tint: .yellow)
                        }
                    } header: {
                        sectionHeader("Favorites", systemImage: "star.fill")
                    }
                }
                if !registry.recentDescriptors.isEmpty {
                    Section {
                        ForEach(registry.recentDescriptors) { descriptor in
                            row(descriptor, tint: colorForCategory(descriptor.category))
                        }
                    } header: {
                        sectionHeader("Recent", systemImage: "clock")
                    }
                }
            }

            ForEach(ToolCategory.allCases) { category in
                let tools = registry.descriptors(for: category)
                if !tools.isEmpty {
                    Section {
                        ForEach(tools) { descriptor in
                            row(descriptor, tint: colorForCategory(category))
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

    private func row(_ descriptor: ToolDescriptor, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: descriptor.icon)
                .font(.system(size: 14))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Text(descriptor.name)
                .font(.body)
            Spacer()
            if registry.isFavorite(descriptor.id) {
                Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow.opacity(0.7))
            }
        }
        .tag(descriptor.id)
        .contextMenu {
            Button(registry.isFavorite(descriptor.id) ? "Remove from Favorites" : "Add to Favorites",
                   systemImage: registry.isFavorite(descriptor.id) ? "star.slash" : "star") {
                registry.toggleFavorite(descriptor.id)
            }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, systemImage: String) -> some View {
        Label {
            Text(title).font(.caption).fontWeight(.semibold).textCase(.uppercase).foregroundStyle(.secondary)
        } icon: {
            Image(systemName: systemImage).font(.caption2).foregroundStyle(.tertiary)
        }
    }

    private func colorForCategory(_ category: ToolCategory) -> Color {
        switch category {
        case .crypto: .blue
        case .apiClient: .green
        case .conversion: .orange
        case .developer: .purple
        case .generators: .teal
        }
    }
}
