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
            Label(
                copied ? "Copied" : "Copy",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(copied ? .green : .secondary)
    }
}
