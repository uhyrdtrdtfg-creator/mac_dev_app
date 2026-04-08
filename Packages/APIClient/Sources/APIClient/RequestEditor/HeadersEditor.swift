import SwiftUI

struct HeadersEditor: View {
    @Binding var headers: [KeyValuePair]
    var body: some View { KeyValueEditor(pairs: $headers, keyPlaceholder: "Header", valuePlaceholder: "Value") }
}
