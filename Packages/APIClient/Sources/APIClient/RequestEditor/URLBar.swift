import SwiftUI

struct URLBar: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    let onSend: () -> Void
    let isSending: Bool

    var body: some View {
        HStack(spacing: 0) {
            // Method selector
            Picker("Method", selection: $method) {
                ForEach(HTTPMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.menu)
            .fixedSize()
            .font(.system(.body, design: .monospaced).weight(.bold))
            .foregroundStyle(method.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(method.color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            // URL input
            TextField("https://api.example.com/endpoint", text: $url)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .onSubmit { onSend() }

            // Send button
            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 56)
                } else {
                    Text("Send")
                        .fontWeight(.semibold)
                        .frame(width: 56)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isSending || url.isEmpty)
        }
        .padding(6)
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.separator, lineWidth: 0.5))
    }
}

extension HTTPMethod {
    var color: Color {
        switch self {
        case .get: .green
        case .post: .orange
        case .put: .blue
        case .patch: .purple
        case .delete: .red
        case .head: .secondary
        case .options: .secondary
        }
    }
}
