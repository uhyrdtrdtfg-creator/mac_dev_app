import SwiftUI

struct KeyValueEditor: View {
    @Binding var pairs: [KeyValuePair]
    let keyPlaceholder: String
    let valuePlaceholder: String

    init(pairs: Binding<[KeyValuePair]>, keyPlaceholder: String = "Key", valuePlaceholder: String = "Value") {
        self._pairs = pairs; self.keyPlaceholder = keyPlaceholder; self.valuePlaceholder = valuePlaceholder
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Color.clear.frame(width: 36)
                Text(keyPlaceholder)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                Text(valuePlaceholder)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                Color.clear.frame(width: 36)
            }
            .padding(.vertical, 8)
            .background(.fill.quaternary)

            Divider()

            // Rows
            ForEach($pairs) { $pair in
                HStack(spacing: 0) {
                    Toggle("", isOn: $pair.isEnabled)
                        .labelsHidden()
                        .controlSize(.small)
                        .frame(width: 36)

                    TextField(keyPlaceholder, text: $pair.key)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)

                    Divider().frame(height: 24)

                    TextField(valuePlaceholder, text: $pair.value)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)

                    Button {
                        pairs.removeAll { $0.id == pair.id }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .foregroundStyle(.quaternary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 36)
                }

                Divider()
            }

            // Add button
            Button {
                pairs.append(KeyValuePair())
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }
}
