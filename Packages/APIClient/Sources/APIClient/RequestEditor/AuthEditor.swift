import SwiftUI

enum AuthMethod: String, CaseIterable, Identifiable {
    case none = "None"; case bearer = "Bearer Token"; case basic = "Basic Auth"; case apiKey = "API Key"
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
        VStack(alignment: .leading, spacing: 8) {
            Picker("Auth", selection: $authMethod) { ForEach(AuthMethod.allCases) { m in Text(m.rawValue).tag(m) } }.pickerStyle(.segmented).frame(width: 400)
            switch authMethod {
            case .none: ContentUnavailableView("No Authentication", systemImage: "lock.open")
            case .bearer: TextField("Token", text: $bearerToken).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            case .basic: HStack { TextField("Username", text: $basicUsername).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)); SecureField("Password", text: $basicPassword).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)) }
            case .apiKey: HStack { TextField("Key", text: $apiKeyName).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)); TextField("Value", text: $apiKeyValue).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)); Picker("", selection: $apiKeyLocation) { Text("Header").tag(APIKeyLocation.header); Text("Query").tag(APIKeyLocation.queryParam) }.frame(width: 120) }
            }
        }
    }
}
