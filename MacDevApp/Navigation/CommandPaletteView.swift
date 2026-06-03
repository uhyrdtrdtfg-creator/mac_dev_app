import SwiftUI
import DevAppCore

struct CommandPaletteView: View {
    @Bindable var registry: ToolRegistry
    @Binding var isPresented: Bool

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var fieldFocused: Bool

    private var results: [ToolDescriptor] {
        guard !query.isEmpty else {
            // Show recents first, then everything.
            let recents = registry.recentDescriptors
            let rest = registry.descriptors.filter { d in !recents.contains(where: { $0.id == d.id }) }
            return recents + rest
        }
        let q = query.lowercased()
        return registry.descriptors.filter { descriptor in
            descriptor.searchKeywords.contains { $0.lowercased().contains(q) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Jump to a tool…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($fieldFocused)
                    .onSubmit { commit() }
                Text("esc").font(.caption2).foregroundStyle(.tertiary)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .padding(14)

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, descriptor in
                            HStack(spacing: 10) {
                                Image(systemName: descriptor.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(color(descriptor.category))
                                    .frame(width: 22, height: 22)
                                    .background(color(descriptor.category).opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 5))
                                Text(descriptor.name)
                                Spacer()
                                Text(descriptor.category.displayName)
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(index == selectedIndex ? Color.accentColor.opacity(0.18) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                            .id(index)
                            .onTapGesture { selectedIndex = index; commit() }
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 360)
                .onChange(of: selectedIndex) { _, newValue in
                    withAnimation(.easeOut(duration: 0.1)) { proxy.scrollTo(newValue, anchor: .center) }
                }
            }
        }
        .frame(width: 560)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.separator, lineWidth: 1))
        .shadow(radius: 30, y: 10)
        .onAppear { fieldFocused = true; selectedIndex = 0 }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.downArrow) { moveSelection(1); return .handled }
        .onKeyPress(.upArrow) { moveSelection(-1); return .handled }
        .onKeyPress(.escape) { isPresented = false; return .handled }
        .onKeyPress(.return) { commit(); return .handled }
    }

    private func moveSelection(_ delta: Int) {
        let count = results.count
        guard count > 0 else { return }
        selectedIndex = (selectedIndex + delta + count) % count
    }

    private func commit() {
        guard results.indices.contains(selectedIndex) else { return }
        registry.selectedToolID = results[selectedIndex].id
        isPresented = false
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
