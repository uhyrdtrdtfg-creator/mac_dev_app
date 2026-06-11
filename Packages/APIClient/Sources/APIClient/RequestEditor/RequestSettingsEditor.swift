import SwiftUI

struct RequestSettingsEditor: View {
    @Binding var settings: RequestSettings

    var body: some View {
        Form {
            Section("Execution") {
                HStack {
                    Text("Timeout")
                    Spacer()
                    TextField("60", value: $settings.timeoutSeconds, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                    Text("seconds").foregroundStyle(.secondary)
                }
                Toggle("Follow redirects", isOn: $settings.followRedirects)
                HStack {
                    Text("Max redirects")
                    Spacer()
                    TextField("10", value: $settings.maxRedirects, format: .number)
                        .frame(width: 70)
                        .multilineTextAlignment(.trailing)
                }
                .disabled(!settings.followRedirects)
            }

            Section("TLS") {
                Toggle("Disable SSL certificate verification", isOn: $settings.insecureSSL)
                if settings.insecureSSL {
                    Label("Server identity is not verified — use only for trusted local servers.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Cookies") {
                Toggle("Send matching stored cookies", isOn: $settings.sendCookies)
                Toggle("Store cookies from responses", isOn: $settings.storeCookies)
                Text("A manually added Cookie header always wins over the cookie jar.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
