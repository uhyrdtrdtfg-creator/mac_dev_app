import SwiftUI
import SwiftData
import DevAppCore

public struct APIClientView: View {
    @Environment(\.modelContext) private var modelContext

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
    @State private var preScript = ""
    @State private var postScript = ""
    @State private var consoleLogs: [ScriptConsoleOutput] = []
    @State private var response: HTTPResponse?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var lastCurlCommand: String?
    @State private var showImportCurl = false
    @State private var curlImportText = ""
    @State private var showHistory = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
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
                    showHistory.toggle()
                } label: {
                    Label("History", systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

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

            // Main content with optional history sidebar
            HStack(spacing: 0) {
                if showHistory {
                    HistoryView(
                        onSelect: { item in
                            restoreFromHistory(item)
                        },
                        onClear: {
                            clearHistory()
                        }
                    )
                    .frame(width: 300)

                    Divider()
                }

                VSplitView {
                    RequestEditorView(
                        method: $method, url: $url, queryParams: $queryParams, headers: $headers,
                        bodyType: $bodyType, jsonBody: $jsonBody, formDataPairs: $formDataPairs, rawBody: $rawBody,
                        authMethod: $authMethod, bearerToken: $bearerToken, basicUsername: $basicUsername, basicPassword: $basicPassword,
                        apiKeyName: $apiKeyName, apiKeyValue: $apiKeyValue, apiKeyLocation: $apiKeyLocation,
                        preScript: $preScript, postScript: $postScript, consoleLogs: consoleLogs,
                        isSending: isSending, onSend: sendRequest
                    )
                    .frame(minHeight: 220)

                    ResponseView(response: response, error: errorMessage, curlCommand: lastCurlCommand) { rewritten in
                        response = rewritten
                    }
                    .frame(minHeight: 180)
                }
            }
        }
    }

    private func sendRequest() {
        isSending = true
        response = nil
        errorMessage = nil
        lastCurlCommand = nil
        consoleLogs = []

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
                var request = try HTTPClientService.buildURLRequest(
                    method: method, url: url, headers: headers,
                    queryParams: queryParams, body: currentBody, auth: currentAuth
                )

                // Run pre-request script
                if !preScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    var scriptCtx = ScriptContext(
                        requestMethod: method.rawValue,
                        requestURL: url,
                        requestHeaders: Dictionary(uniqueKeysWithValues: headers.filter(\.isEnabled).map { ($0.key, $0.value) })
                    )
                    if case .json(let json) = currentBody { scriptCtx.requestBody = json }

                    let preResult = ScriptEngine.runPreScriptCompat(preScript, context: scriptCtx)
                    consoleLogs.append(contentsOf: preResult.logs)

                    // Rebuild request if script modified it
                    let updatedCtx = preResult.context
                    if updatedCtx.requestURL != url || updatedCtx.requestMethod != method.rawValue {
                        let updatedMethod = HTTPMethod(rawValue: updatedCtx.requestMethod) ?? method
                        let updatedHeaders = updatedCtx.requestHeaders.map { KeyValuePair(key: $0.key, value: $0.value) }
                        let updatedBody: RequestBody? = updatedCtx.requestBody.map { .json($0) } ?? currentBody
                        request = try HTTPClientService.buildURLRequest(
                            method: updatedMethod, url: updatedCtx.requestURL,
                            headers: updatedHeaders, queryParams: [],
                            body: updatedBody, auth: currentAuth
                        )
                    }
                }

                lastCurlCommand = CurlHelper.export(request)
                let httpResponse = try await HTTPClientService.send(request)
                response = httpResponse

                // Run post-request script
                if !postScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let postCtx = ScriptContext(
                        requestMethod: method.rawValue,
                        requestURL: url,
                        requestHeaders: [:],
                        responseStatus: httpResponse.statusCode,
                        responseBody: String(data: httpResponse.body, encoding: .utf8),
                        responseHeaders: httpResponse.headers,
                        responseDuration: httpResponse.duration
                    )
                    let postLogs = ScriptEngine.runPostScript(postScript, context: postCtx)
                    consoleLogs.append(contentsOf: postLogs)
                }

                // Save to history
                saveToHistory(httpResponse)

            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func saveToHistory(_ httpResponse: HTTPResponse) {
        let history = HTTPHistoryModel(
            requestMethod: method.rawValue,
            requestURL: url,
            responseStatus: httpResponse.statusCode,
            duration: httpResponse.duration,
            responseSize: httpResponse.bodySize
        )
        history.responseBody = httpResponse.body
        history.responseHeadersJSON = try? JSONEncoder().encode(
            httpResponse.headers.map { KeyValuePair(key: $0.key, value: $0.value) }
        )
        history.requestHeadersJSON = try? JSONEncoder().encode(headers)
        if case .json(let json) = RequestBody.json(jsonBody) {
            history.requestBodyJSON = json.data(using: .utf8)
        }
        modelContext.insert(history)
    }

    private func restoreFromHistory(_ item: HTTPHistoryModel) {
        method = HTTPMethod(rawValue: item.requestMethod) ?? .get
        url = item.requestURL
        if let data = item.requestHeadersJSON,
           let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: data) {
            headers = decoded
        }
        response = nil
        errorMessage = nil
    }

    private func clearHistory() {
        do {
            try modelContext.delete(model: HTTPHistoryModel.self)
        } catch {
            print("Failed to clear history: \(error)")
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
