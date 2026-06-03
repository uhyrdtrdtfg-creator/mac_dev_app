import SwiftUI

/// Shared bus for "send output to another tool" hand-offs.
/// The app sets `destinations` (tools that can receive text) and `onSelect`
/// (switches the active tool); tools call `send`/`consume`.
@Observable
public final class ToolHandoff {
    public struct Destination: Identifiable, Sendable, Hashable {
        public let id: String
        public let name: String
        public let icon: String
        public init(id: String, name: String, icon: String) {
            self.id = id; self.name = name; self.icon = icon
        }
    }

    public var destinations: [Destination] = []
    public var onSelect: ((String) -> Void)?
    private var pending: [String: String] = [:]

    public init() {}

    /// Stash `text` for `toolID` and switch to it.
    public func send(_ text: String, to toolID: String) {
        pending[toolID] = text
        onSelect?(toolID)
    }

    /// Retrieve and clear any text waiting for `toolID`.
    public func consume(_ toolID: String) -> String? {
        guard let text = pending[toolID] else { return nil }
        pending[toolID] = nil
        return text
    }

    public func destinationsExcluding(_ toolID: String?) -> [Destination] {
        destinations.filter { $0.id != toolID }
    }
}

public extension EnvironmentValues {
    @Entry var toolHandoff: ToolHandoff = ToolHandoff()
}

/// A compact menu button that sends `text` to another registered tool.
public struct SendToMenu: View {
    @Environment(\.toolHandoff) private var handoff
    private let text: String
    private let excludingToolID: String?

    public init(text: String, excluding toolID: String? = nil) {
        self.text = text
        self.excludingToolID = toolID
    }

    public var body: some View {
        let targets = handoff.destinationsExcluding(excludingToolID)
        Menu {
            ForEach(targets) { dest in
                Button {
                    handoff.send(text, to: dest.id)
                } label: {
                    Label(dest.name, systemImage: dest.icon)
                }
            }
        } label: {
            Label("Send to", systemImage: "arrow.turn.up.right")
                .labelStyle(.iconOnly)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Send to another tool")
        .disabled(text.isEmpty || targets.isEmpty)
    }
}
