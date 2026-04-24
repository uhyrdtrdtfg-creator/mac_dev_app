import SwiftUI
import SwiftData

struct RequestTabBarView: View {
    let tabs: [OpenTabModel]
    let activeTabID: UUID?
    let onSelect: (OpenTabModel) -> Void
    let onClose: (OpenTabModel) -> Void
    let onNew: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(tabs) { tab in
                            TabChip(
                                tab: tab,
                                isActive: tab.id == activeTabID,
                                onSelect: { onSelect(tab) },
                                onClose: { onClose(tab) }
                            )
                            .id(tab.id)
                        }
                    }
                    .padding(.horizontal, 6)
                }
                .onChange(of: activeTabID) { _, newID in
                    if let id = newID {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .center)
                        }
                    }
                }
            }

            Divider()
                .frame(height: 20)
                .padding(.horizontal, 4)

            Button(action: onNew) {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .help("New Request Tab")
            .padding(.trailing, 8)
        }
        .frame(height: 34)
        .background(.background.secondary)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}

private struct TabChip: View {
    let tab: OpenTabModel
    let isActive: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 6) {
            Text(tab.method)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(methodColor)

            Text(chipTitle)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .foregroundStyle(isActive ? .primary : .secondary)
                .frame(maxWidth: 140, alignment: .leading)

            ZStack {
                if tab.isDirty && !isHovering {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 7, height: 7)
                }
                if isHovering {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 14, height: 14)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Close Tab")
                }
            }
            .frame(width: 14, height: 14)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovering ? Color.secondary.opacity(0.08) : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }

    private var chipTitle: String {
        if !tab.displayName.isEmpty { return tab.displayName }
        let trimmed = tab.url.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty { return "New Request" }
        if let url = URL(string: trimmed), let host = url.host {
            let path = url.path
            return path.isEmpty || path == "/" ? host : host + path
        }
        return trimmed
    }

    private var methodColor: Color {
        switch tab.method.uppercased() {
        case "GET": return .green
        case "POST": return .orange
        case "PUT": return .blue
        case "PATCH": return .purple
        case "DELETE": return .red
        default: return .secondary
        }
    }
}
