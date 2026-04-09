import SwiftUI

enum RequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case body = "Body"
    case auth = "Auth"
    case scripts = "Scripts"

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
    @Binding var preScript: String
    @Binding var postScript: String
    let consoleLogs: [ScriptConsoleOutput]
    let isSending: Bool
    let onSend: () -> Void

    @State private var selectedTab: RequestTab = .params

    var body: some View {
        VStack(spacing: 0) {
            URLBar(method: $method, url: $url, onSend: onSend, isSending: isSending)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            // Tab bar
            HStack(spacing: 0) {
                ForEach(RequestTab.allCases) { tab in
                    tabButton(tab)
                }
                Spacer()
            }
            .padding(.horizontal, 12)

            Divider()

            // Content
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
                    case .scripts:
                        ScriptEditorView(preScript: $preScript, postScript: $postScript, consoleLogs: consoleLogs)
                    }
                }
                .padding(16)
            }
        }
    }

    private func tabButton(_ tab: RequestTab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            Text(tab.rawValue)
                .font(.subheadline)
                .fontWeight(selectedTab == tab ? .semibold : .regular)
                .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if selectedTab == tab {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(height: 2)
                            .offset(y: 1)
                    }
                }
        }
        .buttonStyle(.plain)
    }
}
