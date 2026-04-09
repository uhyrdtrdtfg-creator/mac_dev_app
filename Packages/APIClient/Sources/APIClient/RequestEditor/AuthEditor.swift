import SwiftUI

enum AuthMethod: String, CaseIterable, Identifiable {
    case none = "None"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"

    var id: String { rawValue }
}

struct AuthEditor: View {
    @Binding var authMethod: AuthMethod
    @Binding var bearerToken: String
    @Binding var basicUsername: String
    @Binding var basicPassword: String
    @Binding var apiKeyName: String
    @Binding var apiKeyValue: String
    @Binding var apiKeyLocation: APIKeyLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Auth Type", selection: $authMethod) {
                ForEach(AuthMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch authMethod {
            case .none:
                ContentUnavailableView("No Authentication", systemImage: "lock.open")

            case .bearer:
                VStack(alignment: .leading, spacing: 6) {
                    Text("Bearer Token")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                    TextField("Enter token", text: $bearerToken)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                }

            case .basic:
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Username")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("Username", text: $basicUsername)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Password")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        SecureField("Password", text: $basicPassword)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    }
                }

            case .apiKey:
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Key Name")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("X-API-Key", text: $apiKeyName)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Value")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        TextField("Enter API key", text: $apiKeyValue)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add To")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Picker("Location", selection: $apiKeyLocation) {
                            Text("Header").tag(APIKeyLocation.header)
                            Text("Query Param").tag(APIKeyLocation.queryParam)
                        }
                        .labelsHidden()
                        .fixedSize()
                    }
                }
            }
        }
    }
}
