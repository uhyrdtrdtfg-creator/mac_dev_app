import SwiftUI

struct URLBar: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    let onSend: () -> Void
    let isSending: Bool

    var body: some View {
        HStack(spacing: 8) {
            Picker("Method", selection: $method) {
                ForEach(HTTPMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()

            TextField("https://api.example.com/endpoint", text: $url)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(8)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { onSend() }

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Send")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || url.isEmpty)
        }
    }
}
