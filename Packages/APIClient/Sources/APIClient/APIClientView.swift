import SwiftUI
import DevAppCore

public struct APIClientView: View {
    @State private var method: HTTPMethod = .get
    @State private var url = ""
    @State private var queryParams: [KeyValuePair] = [KeyValuePair()]
    @State private var headers: [KeyValuePair] = [KeyValuePair()]
    @State private var bodyType: BodyType = .none
    @State private var jsonBody = ""
    @State private var formDataPairs: [KeyValuePair] = [KeyValuePair()]
    @State private var rawBody = ""
    @State private var authMethod: AuthMethod = .none
    @State private var bearerToken = ""
    @State private var basicUsername = ""
    @State private var basicPassword = ""
    @State private var apiKeyName = ""
    @State private var apiKeyValue = ""
    @State private var apiKeyLocation: APIKeyLocation = .header
    @State private var response: HTTPResponse?
    @State private var errorMessage: String?
    @State private var isSending = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HTTP Client")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Send HTTP requests and inspect responses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            VSplitView {
                RequestEditorView(
                    method: $method,
                    url: $url,
                    queryParams: $queryParams,
                    headers: $headers,
                    bodyType: $bodyType,
                    jsonBody: $jsonBody,
                    formDataPairs: $formDataPairs,
                    rawBody: $rawBody,
                    authMethod: $authMethod,
                    bearerToken: $bearerToken,
                    basicUsername: $basicUsername,
                    basicPassword: $basicPassword,
                    apiKeyName: $apiKeyName,
                    apiKeyValue: $apiKeyValue,
                    apiKeyLocation: $apiKeyLocation,
                    isSending: isSending,
                    onSend: sendRequest
                )
                .frame(minHeight: 220)

                ResponseView(response: response, error: errorMessage)
                    .frame(minHeight: 180)
            }
        }
    }

    private func sendRequest() {
        isSending = true
        response = nil
        errorMessage = nil

        let currentBody: RequestBody? = {
            switch bodyType {
            case .none: nil
            case .json: .json(jsonBody)
            case .formData: .formData(formDataPairs)
            case .raw: .raw(rawBody)
            }
        }()

        let currentAuth: AuthType? = {
            switch authMethod {
            case .none: nil
            case .bearer: .bearerToken(bearerToken)
            case .basic: .basicAuth(username: basicUsername, password: basicPassword)
            case .apiKey: .apiKey(key: apiKeyName, value: apiKeyValue, addTo: apiKeyLocation)
            }
        }()

        Task {
            do {
                let request = try HTTPClientService.buildURLRequest(
                    method: method, url: url, headers: headers,
                    queryParams: queryParams, body: currentBody, auth: currentAuth
                )
                response = try await HTTPClientService.send(request)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

extension APIClientView {
    public static let descriptor = ToolDescriptor(
        id: "http-client",
        name: "HTTP Client",
        icon: "network",
        category: .apiClient,
        searchKeywords: ["http", "api", "rest", "request", "get", "post", "接口", "调试", "请求"]
    )
}
