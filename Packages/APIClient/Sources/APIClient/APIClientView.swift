import SwiftUI
import SwiftData
import DevAppCore
import CCommonCryptoAPI

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
    @State private var showSaved = false
    @State private var showSaveDialog = false
    @State private var saveRequestName = ""
    @State private var saveRequestTags = ""
    @State private var rewriteScript = ""
    @State private var rewriteScriptLogs: [ScriptConsoleOutput] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Spacer()

                Button {
                    saveRequestName = ""
                    saveRequestTags = ""
                    showSaveDialog = true
                } label: {
                    Image(systemName: "bookmark.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Save Request")
                .disabled(url.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .popover(isPresented: $showSaveDialog) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Save Request").font(.headline)
                        TextField("Name", text: $saveRequestName)
                            .textFieldStyle(.roundedBorder)
                        TextField("Tags (comma-separated)", text: $saveRequestTags)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Spacer()
                            Button("Cancel") { showSaveDialog = false }
                                .buttonStyle(.bordered)
                            Button("Save") {
                                saveCurrentRequest()
                                showSaveDialog = false
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(saveRequestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding()
                    .frame(width: 300)
                }

                Button {
                    showSaved.toggle()
                    if showSaved { showHistory = false }
                } label: {
                    Image(systemName: "bookmark")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Saved APIs")

                Button {
                    showHistory.toggle()
                    if showHistory { showSaved = false }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("History")

                Button {
                    showImportCurl.toggle()
                } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Import cURL")
                .popover(isPresented: $showImportCurl) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Paste cURL Command").font(.headline)
                        Text("Paste a cURL command to auto-fill the request fields")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        CodeEditorView(text: $curlImportText, fontSize: 11)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
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
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            // Main content with optional sidebars
            HStack(spacing: 0) {
                if showSaved {
                    SavedRequestsView(
                        onSelect: { item in
                            restoreFromSaved(item)
                        }
                    )
                    .frame(width: 300)

                    Divider()
                }

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
                    .frame(maxWidth: .infinity, minHeight: 220)

                    ResponseView(
                        response: response,
                        error: errorMessage,
                        curlCommand: lastCurlCommand,
                        rewriteScript: $rewriteScript,
                        rewriteScriptLogs: rewriteScriptLogs
                    ) { rewritten in
                        response = rewritten
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                }
                .frame(maxWidth: .infinity)
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

                    let updatedCtx = preResult.context
                    let updatedMethod = HTTPMethod(rawValue: updatedCtx.requestMethod) ?? method
                    let updatedHeaders = updatedCtx.requestHeaders.map { KeyValuePair(key: $0.key, value: $0.value) }
                    let updatedBody: RequestBody? = updatedCtx.requestBody.map { .json($0) } ?? currentBody
                    request = try HTTPClientService.buildURLRequest(
                        method: updatedMethod, url: updatedCtx.requestURL,
                        headers: updatedHeaders, queryParams: [],
                        body: updatedBody, auth: nil
                    )
                }

                // Resolve {{variable}} templates AFTER pre-script (env vars are now set)
                let envStore = ScriptEngine.getEnvironmentStore()
                if let finalHeaders = request.allHTTPHeaderFields {
                    for (key, value) in finalHeaders {
                        let resolved = resolveTemplates(value, env: envStore)
                        if resolved != value {
                            request.setValue(resolved, forHTTPHeaderField: key)
                        }
                    }
                }
                if let finalURL = request.url?.absoluteString {
                    let resolvedURL = resolveTemplates(finalURL, env: envStore)
                    if resolvedURL != finalURL, let newURL = URL(string: resolvedURL) {
                        request.url = newURL
                    }
                }
                if let bodyData = request.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
                    let resolvedBody = resolveTemplates(bodyStr, env: envStore)
                    if resolvedBody != bodyStr {
                        request.httpBody = Data(resolvedBody.utf8)
                    }
                }

                lastCurlCommand = CurlHelper.export(request)

                // Debug: verify what we're actually sending matches what script computed
                if !preScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let actualBody = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? "(nil)"
                    let actualURL = request.url?.absoluteString ?? "(nil)"
                    let actualHeaders = request.allHTTPHeaderFields ?? [:]
                    consoleLogs.append(ScriptConsoleOutput(message: "\n[DEBUG] Actual request URL: \(actualURL)"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] Actual body length: \(request.httpBody?.count ?? 0) bytes"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] Actual body SHA256: \(sha256Hex(request.httpBody ?? Data()))"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] Content-Type: \(actualHeaders["Content-Type"] ?? "(not set)")"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] x-acgw-sign: \(actualHeaders["x-acgw-sign"]?.prefix(40) ?? "(not set)")..."))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] x-acgw-timestamp: \(actualHeaders["x-acgw-timestamp"] ?? "(not set)")"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] x-acgw-nonce: \(actualHeaders["x-acgw-nonce"] ?? "(not set)")"))
                    consoleLogs.append(ScriptConsoleOutput(message: "[DEBUG] Header count: \(actualHeaders.count)"))
                }

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

                // Auto-run rewrite script if set
                if !rewriteScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let currentResponse = response {
                    let bodyString = String(data: currentResponse.body, encoding: .utf8) ?? ""
                    let rwCtx = ScriptContext(
                        requestMethod: method.rawValue,
                        requestURL: url,
                        requestHeaders: [:],
                        responseStatus: currentResponse.statusCode,
                        responseBody: bodyString,
                        responseHeaders: currentResponse.headers,
                        responseDuration: currentResponse.duration
                    )
                    let rwResult = ScriptEngine.runRewriteScript(rewriteScript, context: rwCtx)
                    rewriteScriptLogs = rwResult.logs
                    consoleLogs.append(contentsOf: rwResult.logs)

                    let newStatus = rwResult.context.responseStatus ?? currentResponse.statusCode
                    let newBody = Data((rwResult.context.responseBody ?? bodyString).utf8)
                    let newHeaders = rwResult.context.responseHeaders ?? currentResponse.headers
                    response = HTTPResponse(
                        statusCode: newStatus,
                        headers: newHeaders,
                        body: newBody,
                        duration: currentResponse.duration,
                        bodySize: newBody.count,
                        cookies: currentResponse.cookies
                    )
                }

                // Save to history
                saveToHistory(httpResponse)

            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        let hash = data.withUnsafeBytes { ptr -> [UInt8] in
            var hasher = CC_SHA256_CTX()
            CC_SHA256_Init(&hasher)
            CC_SHA256_Update(&hasher, ptr.baseAddress, CC_LONG(data.count))
            var digest = [UInt8](repeating: 0, count: 32)
            CC_SHA256_Final(&digest, &hasher)
            return digest
        }
        return hash.map { String(format: "%02x", $0) }.joined()
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
        // Save scripts
        history.preScript = preScript.isEmpty ? nil : preScript
        history.postScript = postScript.isEmpty ? nil : postScript
        history.rewriteScript = rewriteScript.isEmpty ? nil : rewriteScript
        history.bodyType = bodyType.rawValue
        modelContext.insert(history)
    }

    private func restoreFromHistory(_ item: HTTPHistoryModel) {
        method = HTTPMethod(rawValue: item.requestMethod) ?? .get
        url = item.requestURL
        if let data = item.requestHeadersJSON,
           let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: data) {
            headers = decoded
        }
        if let data = item.requestBodyJSON, let body = String(data: data, encoding: .utf8) {
            jsonBody = body
            bodyType = .json
        }
        if let bt = item.bodyType, let t = BodyType(rawValue: bt) {
            bodyType = t
        }
        // Restore scripts
        preScript = item.preScript ?? ""
        postScript = item.postScript ?? ""
        rewriteScript = item.rewriteScript ?? ""
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

    private func saveCurrentRequest() {
        let saved = SavedRequestModel(
            name: saveRequestName,
            method: method.rawValue,
            url: url
        )
        saved.tagList = saveRequestTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        saved.headers = headers
        saved.bodyType = bodyType.rawValue

        switch bodyType {
        case .none:
            break
        case .json:
            saved.body = .json(jsonBody)
        case .formData:
            saved.body = .formData(formDataPairs)
        case .raw:
            saved.body = .raw(rawBody)
        }

        saved.preScript = preScript.isEmpty ? nil : preScript
        saved.postScript = postScript.isEmpty ? nil : postScript
        saved.rewriteScript = rewriteScript.isEmpty ? nil : rewriteScript

        modelContext.insert(saved)
    }

    private func restoreFromSaved(_ item: SavedRequestModel) {
        method = HTTPMethod(rawValue: item.method) ?? .get
        url = item.url
        headers = item.headers.isEmpty ? [KeyValuePair()] : item.headers

        if let bt = item.bodyType, let t = BodyType(rawValue: bt) {
            bodyType = t
        } else {
            bodyType = .none
        }

        if let body = item.body {
            switch body {
            case .json(let json):
                jsonBody = json
                bodyType = .json
            case .formData(let pairs):
                formDataPairs = pairs
                bodyType = .formData
            case .raw(let raw):
                rawBody = raw
                bodyType = .raw
            case .binary:
                break
            }
        }

        preScript = item.preScript ?? ""
        postScript = item.postScript ?? ""
        rewriteScript = item.rewriteScript ?? ""

        response = nil
        errorMessage = nil
    }

    /// Replace {{variable}} templates with values from pm.environment
    private func resolveTemplates(_ text: String, env: EnvironmentStore) -> String {
        var result = text
        // Match {{variableName}} patterns
        let pattern = /\{\{([^}]+)\}\}/
        for match in text.matches(of: pattern) {
            let key = String(match.1).trimmingCharacters(in: .whitespaces)
            if let value = env.get(key) {
                result = result.replacingOccurrences(of: String(match.0), with: value)
            }
        }
        return result
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
