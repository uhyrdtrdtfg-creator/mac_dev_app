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
            HStack(spacing: 0) {
                Toggle("", isOn: .constant(true)).labelsHidden().frame(width: 30).hidden()
                Text(keyPlaceholder).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
                Text(valuePlaceholder).font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 8)
                Spacer().frame(width: 30)
            }.padding(.vertical, 4)
            Divider()
            ForEach($pairs) { $pair in
                HStack(spacing: 0) {
                    Toggle("", isOn: $pair.isEnabled).labelsHidden().frame(width: 30)
                    TextField(keyPlaceholder, text: $pair.key).textFieldStyle(.plain).font(.system(.body, design: .monospaced)).padding(4)
                    TextField(valuePlaceholder, text: $pair.value).textFieldStyle(.plain).font(.system(.body, design: .monospaced)).padding(4)
                    Button { pairs.removeAll { $0.id == pair.id } } label: { Image(systemName: "minus.circle").foregroundStyle(.secondary) }.buttonStyle(.plain).frame(width: 30)
                }.padding(.vertical, 2)
                Divider()
            }
            Button { pairs.append(KeyValuePair()) } label: { Label("Add", systemImage: "plus").font(.caption) }.buttonStyle(.borderless).padding(8)
        }.background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
