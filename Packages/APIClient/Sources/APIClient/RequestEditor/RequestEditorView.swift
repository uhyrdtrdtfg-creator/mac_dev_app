import SwiftUI

enum RequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case body = "Body"
    case auth = "Auth"

    var id: String { rawValue }
}

struct RequestEditorView: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    @Binding var queryParams: [KeyValuePair]
    @Binding var headers: [KeyValuePair]
    @Binding var bodyType: BodyType
    @Binding var jsonBody: String
    @Binding var formDataPairs: [KeyValuePair]
    @Binding var rawBody: String
    @Binding var authMethod: AuthMethod
    @Binding var bearerToken: String
    @Binding var basicUsername: String
    @Binding var basicPassword: String
    @Binding var apiKeyName: String
    @Binding var apiKeyValue: String
    @Binding var apiKeyLocation: APIKeyLocation
    let isSending: Bool
    let onSend: () -> Void

    @State private var selectedTab: RequestTab = .params

    var body: some View {
        VStack(spacing: 0) {
            URLBar(method: $method, url: $url, onSend: onSend, isSending: isSending)
                .padding(12)

            Picker("Request Tab", selection: $selectedTab) {
                ForEach(RequestTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 12)

            Divider()
                .padding(.top, 8)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .params:
                        KeyValueEditor(pairs: $queryParams, keyPlaceholder: "Parameter", valuePlaceholder: "Value")
                    case .headers:
                        HeadersEditor(headers: $headers)
                    case .body:
                        BodyEditor(bodyType: $bodyType, jsonBody: $jsonBody, formDataPairs: $formDataPairs, rawBody: $rawBody)
                    case .auth:
                        AuthEditor(authMethod: $authMethod, bearerToken: $bearerToken, basicUsername: $basicUsername, basicPassword: $basicPassword, apiKeyName: $apiKeyName, apiKeyValue: $apiKeyValue, apiKeyLocation: $apiKeyLocation)
                    }
                }
                .padding(12)
            }
        }
    }
}
