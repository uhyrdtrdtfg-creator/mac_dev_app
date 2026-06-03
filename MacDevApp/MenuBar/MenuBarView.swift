import SwiftUI
import AppKit
import DevAppCore

/// The rich panel shown from the menu-bar icon: search, clipboard-aware
/// suggestions, recents/favorites, and quick actions.
struct MenuBarView: View {
    @Bindable var registry: ToolRegistry
    let handoff: ToolHandoff

    @Environment(\.openWindow) private var openWindow

    @State private var query = ""
    @State private var suggestions: [ClipboardSuggestion] = []
    @State private var clipboardText = ""

    private var searchResults: [ToolDescriptor] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        return registry.descriptors.filter { d in
            d.searchKeywords.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    if query.isEmpty {
                        if !suggestions.isEmpty { clipboardSection }
                        toolSection("Recents", registry.recentDescriptors)
                        toolSection("Favorites", registry.favoriteDescriptors)
                    } else {
                        toolSection("Results", searchResults)
                    }
                }
                .padding(8)
            }
            .frame(maxHeight: 360)

            Divider()
            footer
        }
        .frame(width: 320)
        .onAppear(perform: refreshSuggestions)
    }

    // MARK: - Sections

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search tools…", text: $query)
                .textFieldStyle(.plain)
        }
        .padding(10)
    }

    private var clipboardSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionHeader("From Clipboard")
            ForEach(suggestions) { suggestion in
                row(icon: suggestion.icon, title: suggestion.label, tint: .accentColor) {
                    open(toolID: suggestion.toolID, prefill: clipboardText)
                }
            }
        }
    }

    @ViewBuilder
    private func toolSection(_ title: String, _ tools: [ToolDescriptor]) -> some View {
        if !tools.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                sectionHeader(title)
                ForEach(tools) { tool in
                    row(icon: tool.icon, title: nil, localized: tool.name, tint: color(tool.category)) {
                        open(toolID: tool.id)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 0) {
            footerButton("Open", systemImage: "macwindow") {
                showMainWindow(using: openWindow)
            }
            Divider().frame(height: 18)
            footerButton("Update", systemImage: "arrow.down.circle") {
                AppCoordinator.shared.checkForUpdates?()
            }
            Divider().frame(height: 18)
            footerButton("Quit", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
    }

    // MARK: - Building blocks

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 8)
            .padding(.top, 6)
    }

    private func row(
        icon: String,
        title: String?,
        localized: LocalizedStringKey? = nil,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                    .frame(width: 20, height: 20)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                if let localized { Text(localized) } else if let title { Text(title) }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func footerButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func refreshSuggestions() {
        clipboardText = NSPasteboard.general.string(forType: .string) ?? ""
        suggestions = ClipboardInspector.detect(clipboardText)
    }

    private func open(toolID: String, prefill: String? = nil) {
        showMainWindow(using: openWindow)
        if let prefill, !prefill.isEmpty {
            handoff.send(prefill, to: toolID)
        } else {
            registry.selectedToolID = toolID
        }
    }

    private func color(_ category: ToolCategory) -> Color {
        switch category {
        case .crypto: .blue
        case .apiClient: .green
        case .conversion: .orange
        case .developer: .purple
        case .generators: .teal
        }
    }
}
