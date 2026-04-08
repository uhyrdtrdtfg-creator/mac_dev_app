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
    @State private var lastCurlCommand: String?
    @State private var showImportCurl = false
    @State private var curlImportText = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with cURL import button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HTTP Client")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Send HTTP requests and inspect responses")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showImportCurl.toggle()
                } label: {
                    Label("Import cURL", systemImage: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .popover(isPresented: $showImportCurl) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste cURL Command").font(.headline)
                        Text("Paste a cURL command to auto-fill the request fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $curlImportText)
                            .font(.system(.caption, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        HStack {
                            Spacer()
                            Button("Cancel") { showImportCurl = false; curlImportText = "" }
                                .buttonStyle(.bordered)
                            Button("Import") { importCurl(); showImportCurl = false }
                                .buttonStyle(.borderedProminent)
                                .disabled(curlImportText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                    .frame(width: 500, height: 300)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            VSplitView {
                RequestEditorView(
                    method: $method, url: $url, queryParams: $queryParams, headers: $headers,
                    bodyType: $bodyType, jsonBody: $jsonBody, formDataPairs: $formDataPairs, rawBody: $rawBody,
                    authMethod: $authMethod, bearerToken: $bearerToken, basicUsername: $basicUsername, basicPassword: $basicPassword,
                    apiKeyName: $apiKeyName, apiKeyValue: $apiKeyValue, apiKeyLocation: $apiKeyLocation,
                    isSending: isSending, onSend: sendRequest
                )
                .frame(minHeight: 220)

                ResponseView(response: response, error: errorMessage, curlCommand: lastCurlCommand)
                    .frame(minHeight: 180)
            }
        }
    }

    private func sendRequest() {
        isSending = true
        response = nil
        errorMessage = nil
        lastCurlCommand = nil

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
                lastCurlCommand = CurlHelper.export(request)
                response = try await HTTPClientService.send(request)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func importCurl() {
        guard let result = CurlHelper.parse(curlImportText) else { return }

        url = result.url
        method = HTTPMethod(rawValue: result.method) ?? .get

        headers = result.headers.map { KeyValuePair(key: $0.0, value: $0.1) }
        if headers.isEmpty { headers = [KeyValuePair()] }

        if let body = result.body {
            // Check if it's JSON
            if let data = body.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                bodyType = .json
                jsonBody = body
            } else {
                bodyType = .raw
                rawBody = body
            }
        } else {
            bodyType = .none
        }

        curlImportText = ""
    }
}

extension APIClientView {
    public static let descriptor = ToolDescriptor(
        id: "http-client",
        name: "HTTP Client",
        icon: "network",
        category: .apiClient,
        searchKeywords: ["http", "api", "rest", "request", "get", "post", "curl", "接口", "调试", "请求"]
    )
}
