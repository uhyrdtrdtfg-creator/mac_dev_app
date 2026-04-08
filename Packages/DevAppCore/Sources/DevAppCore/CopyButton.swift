import SwiftUI
import AppKit

public struct CopyButton: View {
    let text: String
    @State private var copied = false

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.caption2)
                Text(copied ? "Copied!" : "Copy")
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(copied ? Color.green.opacity(0.15) : Color.secondary.opacity(0.1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(copied ? .green : .secondary)
        .contentTransition(.symbolEffect(.replace))
        .animation(.easeInOut(duration: 0.2), value: copied)
    }
}
