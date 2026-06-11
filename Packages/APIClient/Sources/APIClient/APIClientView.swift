import SwiftUI
import SwiftData
import DevAppCore

public struct APIClientView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \EnvironmentModel.name) private var environments: [EnvironmentModel]
    @Query(sort: \OpenTabModel.sortIndex) private var tabs: [OpenTabModel]

    @State private var activeTabID: UUID?

    @State private var consoleLogs: [ScriptConsoleOutput] = []
    @State private var response: HTTPResponse?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var lastCurlCommand: String?
    @State private var showImportCurl = false
    @State private var curlImportText = ""
    @State private var showCodeGen = false
    @State private var showHistory = false
    @State private var showSaved = false
    @State private var showSaveDialog = false
    @State private var saveRequestName = ""
    @State private var saveRequestTags = ""
    @State private var rewriteScriptLogs: [ScriptConsoleOutput] = []
    @State private var showChains = false
    @State private var selectedChain: ChainModel?
    @State private var debugMode = false
    @State private var showEnvironmentManager = false
    @State private var selectedEnvironment: EnvironmentModel?
    @State private var showCookieManager = false

    public init() {}

    private var activeTab: OpenTabModel? {
        if let id = activeTabID, let t = tabs.first(where: { $0.id == id }) { return t }
        return tabs.first
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            toolbar

            RequestTabBarView(
                tabs: tabs,
                activeTabID: activeTab?.id,
                onSelect: { tab in selectTab(tab) },
                onClose: { tab in closeTab(tab) },
                onNew: { newTab() }
            )

            HStack(spacing: 0) {
                if showSaved {
                    SavedRequestsView(onSelect: { item in restoreFromSaved(item) })
                        .frame(width: 300)
                    Divider()
                }

                if showHistory {
                    HistoryView(
                        onSelect: { item in restoreFromHistory(item) },
                        onClear: { clearHistory() }
                    )
                    .frame(width: 300)
                    Divider()
                }

                if showChains {
                    ChainListView { chain in selectedChain = chain }
                        .frame(width: 250)
                    Divider()
                }

                if let chain = selectedChain {
                    ChainEditorView(chain: chain)
                        .frame(maxWidth: .infinity)
                } else if let tab = activeTab {
                    VSplitView {
                        RequestEditorView(
                            method: methodBinding(tab),
                            url: binding(tab, \.url),
                            queryParams: kvBinding(tab, \.queryParamsJSON),
                            headers: kvBinding(tab, \.headersJSON),
                            bodyType: bodyTypeBinding(tab),
                            jsonBody: binding(tab, \.jsonBody),
                            formDataPairs: kvBinding(tab, \.formDataJSON),
                            rawBody: binding(tab, \.rawBody),
                            graphqlQuery: binding(tab, \.graphqlQuery),
                            graphqlVariables: binding(tab, \.graphqlVariables),
                            multipartParts: multipartBinding(tab),
                            binaryFilePath: binding(tab, \.binaryFilePath),
                            binaryMimeType: binding(tab, \.binaryMimeType),
                            authMethod: authMethodBinding(tab),
                            bearerToken: binding(tab, \.bearerToken),
                            basicUsername: binding(tab, \.basicUsername),
                            basicPassword: binding(tab, \.basicPassword),
                            digestUsername: binding(tab, \.digestUsername),
                            digestPassword: binding(tab, \.digestPassword),
                            apiKeyName: binding(tab, \.apiKeyName),
                            apiKeyValue: binding(tab, \.apiKeyValue),
                            apiKeyLocation: apiKeyLocationBinding(tab),
                            oauthConfig: oauthConfigBinding(tab),
                            preScript: binding(tab, \.preScript),
                            postScript: binding(tab, \.postScript),
                            requestSettings: requestSettingsBinding(tab),
                            consoleLogs: consoleLogs,
                            isSending: isSending,
                            onSend: sendRequest
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)

                        ResponseView(
                            response: response,
                            error: errorMessage,
                            curlCommand: lastCurlCommand,
                            requestURL: tab.url,
                            rewriteScript: binding(tab, \.rewriteScript),
                            rewriteScriptLogs: rewriteScriptLogs
                        ) { rewritten in
                            response = rewritten
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    }
                    .frame(maxWidth: .infinity)
                    .id(tab.id)
                }
            }
        }
        .sheet(isPresented: $showEnvironmentManager) {
            EnvironmentManagerView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .sheet(isPresented: $showCookieManager) {
            CookieManagerView()
                .frame(minWidth: 600, minHeight: 400)
        }
        .onChange(of: selectedEnvironment) { _, newEnv in
            for env in environments { env.isActive = false }
            if let env = newEnv {
                env.isActive = true
                ScriptEngine.setEnvironment(env.variables)
            } else {
                ScriptEngine.setEnvironment([:])
            }
        }
        .onChange(of: activeTab?.id) { _, _ in
            consoleLogs = []
            rewriteScriptLogs = []
            if let tab = activeTab {
                loadResponseFromTab(tab)
            } else {
                response = nil
                errorMessage = nil
                lastCurlCommand = nil
            }
        }
        .onAppear {
            if let activeEnv = environments.first(where: { $0.isActive }) {
                selectedEnvironment = activeEnv
                ScriptEngine.setEnvironment(activeEnv.variables)
            }
            ensureInitialTab()
            if let tab = activeTab {
                loadResponseFromTab(tab)
            }
        }
    }

    // MARK: - Response persistence per tab

    private func loadResponseFromTab(_ tab: OpenTabModel) {
        if let status = tab.lastResponseStatusCode,
           let body = tab.lastResponseBody,
           let duration = tab.lastResponseDuration,
           let size = tab.lastResponseBodySize {
            let headers: [String: String] = {
                if let d = tab.lastResponseHeadersJSON,
                   let pairs = try? JSONDecoder().decode([KeyValuePair].self, from: d) {
                    return Dictionary(uniqueKeysWithValues: pairs.map { ($0.key, $0.value) })
                }
                return [:]
            }()
            let cookies: [String] = {
                if let d = tab.lastResponseCookiesJSON,
                   let arr = try? JSONDecoder().decode([String].self, from: d) {
                    return arr
                }
                return []
            }()
            response = HTTPResponse(
                statusCode: status,
                headers: headers,
                body: body,
                duration: duration,
                bodySize: size,
                cookies: cookies
            )
        } else {
            response = nil
        }
        errorMessage = tab.lastErrorMessage
        lastCurlCommand = tab.lastCurlCommand
    }

    private func storeResponseInTab(_ tab: OpenTabModel, response: HTTPResponse) {
        tab.lastResponseStatusCode = response.statusCode
        tab.lastResponseBody = response.body
        let headerPairs = response.headers.map { KeyValuePair(key: $0.key, value: $0.value) }
        tab.lastResponseHeadersJSON = try? JSONEncoder().encode(headerPairs)
        tab.lastResponseDuration = response.duration
        tab.lastResponseBodySize = response.bodySize
        tab.lastResponseCookiesJSON = try? JSONEncoder().encode(response.cookies)
        tab.lastErrorMessage = nil
        tab.lastCurlCommand = lastCurlCommand
        tab.lastResponseAt = Date()
    }

    private func storeErrorInTab(_ tab: OpenTabModel, message: String) {
        tab.lastErrorMessage = message
        tab.lastResponseAt = Date()
    }

    @ViewBuilder
    private var toolbar: some View {
        HStack(spacing: 8) {
            Toggle(isOn: $debugMode) {
                Image(systemName: "ladybug").font(.caption)
            }
            .toggleStyle(.button)
            .help("Debug Mode")
            .onChange(of: debugMode) { _, newValue in
                HTTPClientService.debugEnabled = newValue
            }

            HStack(spacing: 4) {
                Image(systemName: "globe").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: $selectedEnvironment) {
                    Text("No Environment").tag(nil as EnvironmentModel?)
                    ForEach(environments) { env in
                        Text(env.name).tag(env as EnvironmentModel?)
                    }
                }
                .labelsHidden()
                .frame(width: 120)

                Button {
                    showEnvironmentManager = true
                } label: {
                    Image(systemName: "gearshape").font(.caption)
                }
                .buttonStyle(.plain)
                .help("Manage Environments")
            }

            Button {
                showCookieManager = true
            } label: {
                Image(systemName: "shippingbox").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Cookie Manager")

            Spacer()

            Button {
                saveRequestName = activeTab?.displayName ?? ""
                saveRequestTags = ""
                showSaveDialog = true
            } label: {
                Image(systemName: "bookmark.fill").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Save Request")
            .disabled((activeTab?.url ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                Image(systemName: "bookmark").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Saved APIs")

            Button {
                showHistory.toggle()
                if showHistory { showSaved = false }
            } label: {
                Image(systemName: "clock.arrow.circlepath").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("History")

            Button {
                showImportCurl.toggle()
            } label: {
                Image(systemName: "square.and.arrow.down").font(.caption)
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

            Button {
                showCodeGen = true
            } label: {
                Image(systemName: "curlybraces").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Generate Code")
            .disabled(activeTab == nil)
            .sheet(isPresented: $showCodeGen) {
                CodeGenSheet(request: currentCodeGenRequest())
            }

            Button {
                showChains.toggle()
                if showChains {
                    showSaved = false
                    showHistory = false
                }
                if !showChains {
                    selectedChain = nil
                }
            } label: {
                Image(systemName: "link").font(.caption)
            }
            .buttonStyle(.bordered)
            .help("Chains")

            Button {
                newTab()
            } label: {
                Image(systemName: "plus").font(.caption)
            }
            .buttonStyle(.borderedProminent)
            .help("New Request Tab")
            .keyboardShortcut("t", modifiers: .command)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Tab management

    private func ensureInitialTab() {
        if tabs.isEmpty {
            let tab = OpenTabModel()
            tab.isActive = true
            tab.sortIndex = 0
            modelContext.insert(tab)
            activeTabID = tab.id
        } else if activeTabID == nil {
            let existing = tabs.first(where: { $0.isActive }) ?? tabs.first
            activeTabID = existing?.id
        }
    }

    private func selectTab(_ tab: OpenTabModel) {
        for t in tabs { t.isActive = (t.id == tab.id) }
        activeTabID = tab.id
    }

    private func newTab() {
        let tab = OpenTabModel()
        tab.sortIndex = (tabs.map { $0.sortIndex }.max() ?? -1) + 1
        for t in tabs { t.isActive = false }
        tab.isActive = true
        modelContext.insert(tab)
        activeTabID = tab.id
    }

    private func closeTab(_ tab: OpenTabModel) {
        let wasActive = (tab.id == activeTab?.id)
        let remaining = tabs.filter { $0.id != tab.id }
        modelContext.delete(tab)

        if remaining.isEmpty {
            let blank = OpenTabModel()
            blank.isActive = true
            blank.sortIndex = 0
            modelContext.insert(blank)
            activeTabID = blank.id
        } else if wasActive {
            let next = remaining.first!
            for t in remaining { t.isActive = (t.id == next.id) }
            activeTabID = next.id
        }
    }

    // MARK: - Bindings into active tab

    private func binding(_ tab: OpenTabModel, _ keyPath: ReferenceWritableKeyPath<OpenTabModel, String>) -> Binding<String> {
        Binding(
            get: { tab[keyPath: keyPath] },
            set: { newValue in
                tab[keyPath: keyPath] = newValue
                markDirty(tab)
            }
        )
    }

    private func kvBinding(_ tab: OpenTabModel, _ dataKeyPath: ReferenceWritableKeyPath<OpenTabModel, Data?>) -> Binding<[KeyValuePair]> {
        Binding(
            get: {
                if let d = tab[keyPath: dataKeyPath],
                   let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: d) {
                    return decoded
                }
                return [KeyValuePair()]
            },
            set: { newValue in
                tab[keyPath: dataKeyPath] = try? JSONEncoder().encode(newValue)
                markDirty(tab)
            }
        )
    }

    private func methodBinding(_ tab: OpenTabModel) -> Binding<HTTPMethod> {
        Binding(
            get: { HTTPMethod(rawValue: tab.method) ?? .get },
            set: { newValue in
                tab.method = newValue.rawValue
                markDirty(tab)
            }
        )
    }

    private func bodyTypeBinding(_ tab: OpenTabModel) -> Binding<BodyType> {
        Binding(
            get: { BodyType(rawValue: tab.bodyType) ?? .none },
            set: { newValue in
                tab.bodyType = newValue.rawValue
                markDirty(tab)
            }
        )
    }

    private func authMethodBinding(_ tab: OpenTabModel) -> Binding<AuthMethod> {
        Binding(
            get: { AuthMethod(rawValue: tab.authMethod) ?? .none },
            set: { newValue in
                tab.authMethod = newValue.rawValue
                markDirty(tab)
            }
        )
    }

    private func apiKeyLocationBinding(_ tab: OpenTabModel) -> Binding<APIKeyLocation> {
        Binding(
            get: { APIKeyLocation(rawValue: tab.apiKeyLocation) ?? .header },
            set: { newValue in
                tab.apiKeyLocation = newValue.rawValue
                markDirty(tab)
            }
        )
    }

    private func multipartBinding(_ tab: OpenTabModel) -> Binding<[MultipartPart]> {
        Binding(
            get: { tab.multipartParts },
            set: { newValue in
                tab.multipartParts = newValue
                markDirty(tab)
            }
        )
    }

    private func oauthConfigBinding(_ tab: OpenTabModel) -> Binding<OAuth2Config> {
        Binding(
            get: { tab.oauthConfig },
            set: { newValue in
                tab.oauthConfig = newValue
                markDirty(tab)
            }
        )
    }

    private func requestSettingsBinding(_ tab: OpenTabModel) -> Binding<RequestSettings> {
        Binding(
            get: { tab.requestSettings },
            set: { newValue in
                tab.requestSettings = newValue
                markDirty(tab)
            }
        )
    }

    private func upsertCookies(_ captured: [CookieRecord]) {
        let existing = (try? modelContext.fetch(FetchDescriptor<CookieModel>())) ?? []
        for record in captured {
            if let match = existing.first(where: { $0.name == record.name && $0.domain == record.domain && $0.path == record.path }) {
                match.value = record.value
                match.expiresAt = record.expiresAt
                match.isSecure = record.isSecure
                match.updatedAt = Date()
            } else {
                modelContext.insert(CookieModel(
                    domain: record.domain, name: record.name, value: record.value,
                    path: record.path, expiresAt: record.expiresAt, isSecure: record.isSecure
                ))
            }
        }
    }

    private func markDirty(_ tab: OpenTabModel) {
        tab.isDirty = true
        tab.updatedAt = Date()
    }

    // MARK: - Send

    private func sendRequest() {
        guard let tab = activeTab else { return }
        isSending = true
        response = nil
        errorMessage = nil
        lastCurlCommand = nil
        consoleLogs = []
        rewriteScriptLogs = []
        tab.lastResponseStatusCode = nil
        tab.lastResponseBody = nil
        tab.lastResponseHeadersJSON = nil
        tab.lastResponseDuration = nil
        tab.lastResponseBodySize = nil
        tab.lastResponseCookiesJSON = nil
        tab.lastErrorMessage = nil
        tab.lastCurlCommand = nil

        let bodyTypeEnum = BodyType(rawValue: tab.bodyType) ?? .none
        let authMethodEnum = AuthMethod(rawValue: tab.authMethod) ?? .none
        let apiKeyLocEnum = APIKeyLocation(rawValue: tab.apiKeyLocation) ?? .header

        let currentBody: RequestBody? = {
            switch bodyTypeEnum {
            case .none: nil
            case .json: .json(tab.jsonBody)
            case .formData: .formData(tab.formDataPairs)
            case .raw: .raw(tab.rawBody)
            case .graphql: .graphql(query: tab.graphqlQuery, variables: tab.graphqlVariables)
            case .multipart: .multipart(tab.multipartParts)
            case .binary: nil // read from binaryFilePath at send time below
            }
        }()

        let currentAuth: AuthType? = {
            switch authMethodEnum {
            case .none: nil
            case .bearer: .bearerToken(tab.bearerToken)
            case .basic: .basicAuth(username: tab.basicUsername, password: tab.basicPassword)
            case .digest: .digestAuth(username: tab.digestUsername, password: tab.digestPassword)
            case .apiKey: .apiKey(key: tab.apiKeyName, value: tab.apiKeyValue, addTo: apiKeyLocEnum)
            case .oauth2: .oauth2(tab.oauthConfig)
            }
        }()

        let method = HTTPMethod(rawValue: tab.method) ?? .get
        let url = tab.url
        let headers = BinaryBodyFile.headers(tab.headers, addingContentType: bodyTypeEnum == .binary ? tab.binaryMimeType : "")
        let binaryFilePath = tab.binaryFilePath
        let queryParams = tab.queryParams
        let preScript = tab.preScript
        let postScript = tab.postScript
        let rewriteScript = tab.rewriteScript
        let settings = tab.requestSettings
        let storedCookies: [CookieRecord] = {
            guard settings.sendCookies else { return [] }
            let all = (try? modelContext.fetch(FetchDescriptor<CookieModel>())) ?? []
            return all.map { CookieRecord(domain: $0.domain, name: $0.name, value: $0.value, path: $0.path, expiresAt: $0.expiresAt, isSecure: $0.isSecure) }
        }()

        Task {
            var requestBody = currentBody
            if bodyTypeEnum == .binary {
                do { requestBody = .binary(try BinaryBodyFile.load(path: binaryFilePath)) }
                catch {
                    errorMessage = error.localizedDescription
                    storeErrorInTab(tab, message: error.localizedDescription)
                    isSending = false
                    return
                }
            }
            let result = await RequestExecutor.execute(
                method: method,
                url: url,
                headers: headers,
                queryParams: queryParams,
                body: requestBody,
                auth: currentAuth,
                preScript: preScript.isEmpty ? nil : preScript,
                postScript: postScript.isEmpty ? nil : postScript,
                rewriteScript: rewriteScript.isEmpty ? nil : rewriteScript,
                settings: settings,
                storedCookies: storedCookies
            )

            if !result.capturedCookies.isEmpty { upsertCookies(result.capturedCookies) }
            consoleLogs = result.consoleLogs
            if let resp = result.response {
                response = resp
                storeResponseInTab(tab, response: resp)
                saveToHistory(resp, tab: tab)
            }
            if let err = result.error {
                errorMessage = err
                storeErrorInTab(tab, message: err)
            }
            isSending = false
        }
    }

    private func saveToHistory(_ httpResponse: HTTPResponse, tab: OpenTabModel) {
        let history = HTTPHistoryModel(
            requestMethod: tab.method,
            requestURL: tab.url,
            responseStatus: httpResponse.statusCode,
            duration: httpResponse.duration,
            responseSize: httpResponse.bodySize
        )
        history.responseBody = httpResponse.body
        history.responseHeadersJSON = try? JSONEncoder().encode(
            httpResponse.headers.map { KeyValuePair(key: $0.key, value: $0.value) }
        )
        history.requestHeadersJSON = try? JSONEncoder().encode(tab.headers)
        history.queryParamsJSON = try? JSONEncoder().encode(tab.queryParams)

        let bodyTypeEnum = BodyType(rawValue: tab.bodyType) ?? .none
        switch bodyTypeEnum {
        case .none: break
        case .json: history.requestBodyJSON = tab.jsonBody.data(using: .utf8)
        case .formData: history.formDataJSON = try? JSONEncoder().encode(tab.formDataPairs)
        case .raw: history.rawBody = tab.rawBody
        // HTTPHistoryModel's CloudKit schema is frozen — store the GraphQL envelope through the JSON pathway.
        case .graphql: history.requestBodyJSON = try? GraphQLEnvelope.build(query: tab.graphqlQuery, variables: tab.graphqlVariables)
        // Frozen schema reuse: multipart parts ride in requestBodyJSON as encoded [MultipartPart].
        case .multipart: history.requestBodyJSON = try? JSONEncoder().encode(tab.multipartParts)
        // Frozen schema reuse: binary bytes ride in requestBodyJSON, the source path in rawBody.
        case .binary:
            history.rawBody = tab.binaryFilePath
            history.requestBodyJSON = try? BinaryBodyFile.load(path: tab.binaryFilePath)
        }

        history.preScript = tab.preScript.isEmpty ? nil : tab.preScript
        history.postScript = tab.postScript.isEmpty ? nil : tab.postScript
        history.rewriteScript = tab.rewriteScript.isEmpty ? nil : tab.rewriteScript
        history.bodyType = tab.bodyType
        modelContext.insert(history)
    }

    private func restoreFromHistory(_ item: HTTPHistoryModel) {
        let tab = OpenTabModel()
        tab.sortIndex = (tabs.map { $0.sortIndex }.max() ?? -1) + 1
        tab.method = item.requestMethod
        tab.url = item.requestURL

        if let data = item.requestHeadersJSON,
           let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: data) {
            tab.headers = decoded
        } else {
            tab.headers = [KeyValuePair()]
        }

        if let data = item.queryParamsJSON,
           let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: data) {
            tab.queryParams = decoded
        } else {
            tab.queryParams = [KeyValuePair()]
        }

        if let bt = item.bodyType, let t = BodyType(rawValue: bt) {
            tab.bodyType = t.rawValue
            switch t {
            case .none:
                break
            case .json:
                if let data = item.requestBodyJSON, let body = String(data: data, encoding: .utf8) {
                    tab.jsonBody = body
                }
            case .formData:
                if let data = item.formDataJSON,
                   let decoded = try? JSONDecoder().decode([KeyValuePair].self, from: data) {
                    tab.formDataPairs = decoded
                }
            case .raw:
                tab.rawBody = item.rawBody ?? ""
            case .graphql:
                if let data = item.requestBodyJSON, let (query, variables) = GraphQLEnvelope.decompose(data) {
                    tab.graphqlQuery = query
                    tab.graphqlVariables = variables
                }
            case .multipart:
                if let data = item.requestBodyJSON,
                   let parts = try? JSONDecoder().decode([MultipartPart].self, from: data) {
                    tab.multipartParts = parts
                }
            case .binary:
                if let path = item.rawBody, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
                    tab.binaryFilePath = path
                    tab.binaryMimeType = MultipartEncoder.mimeType(forPath: path)
                } else if let data = item.requestBodyJSON {
                    tab.restoreBinaryBody(data)
                } else {
                    tab.lastErrorMessage = "Binary request body could not be restored from history — the original file is gone."
                }
            }
        } else {
            tab.bodyType = BodyType.none.rawValue
        }

        tab.preScript = item.preScript ?? ""
        tab.postScript = item.postScript ?? ""
        tab.rewriteScript = item.rewriteScript ?? ""
        tab.isDirty = true

        for t in tabs { t.isActive = false }
        tab.isActive = true
        modelContext.insert(tab)
        activeTabID = tab.id

        response = nil
        errorMessage = nil
        consoleLogs = []
    }

    private func clearHistory() {
        do {
            try modelContext.delete(model: HTTPHistoryModel.self)
        } catch {
            print("Failed to clear history: \(error)")
        }
    }

    private func currentCodeGenRequest() -> CodeGenRequest {
        guard let tab = activeTab else { return CodeGenRequest(method: .get, url: "") }

        let codeGenBodyType = BodyType(rawValue: tab.bodyType) ?? .none
        let body: RequestBody? = switch codeGenBodyType {
        case .none: nil
        case .json: .json(tab.jsonBody)
        case .formData: .formData(tab.formDataPairs)
        case .raw: .raw(tab.rawBody)
        case .graphql: .graphql(query: tab.graphqlQuery, variables: tab.graphqlVariables)
        case .multipart: .multipart(tab.multipartParts)
        case .binary: .binary((try? BinaryBodyFile.load(path: tab.binaryFilePath)) ?? Data())
        }

        let auth: AuthType? = switch AuthMethod(rawValue: tab.authMethod) ?? .none {
        case .none: nil
        case .bearer: .bearerToken(tab.bearerToken)
        case .basic: .basicAuth(username: tab.basicUsername, password: tab.basicPassword)
        case .digest: .digestAuth(username: tab.digestUsername, password: tab.digestPassword)
        case .apiKey: .apiKey(key: tab.apiKeyName, value: tab.apiKeyValue, addTo: APIKeyLocation(rawValue: tab.apiKeyLocation) ?? .header)
        case .oauth2: .oauth2(tab.oauthConfig)
        }

        return CodeGenRequest(
            method: HTTPMethod(rawValue: tab.method) ?? .get,
            url: tab.url,
            headers: BinaryBodyFile.headers(tab.headers, addingContentType: codeGenBodyType == .binary ? tab.binaryMimeType : ""),
            queryParams: tab.queryParams,
            body: body,
            auth: auth,
            binaryFilePath: tab.binaryFilePath.isEmpty ? nil : tab.binaryFilePath
        )
    }

    private func importCurl() {
        guard let result = CurlHelper.parse(curlImportText), let tab = activeTab else { return }

        tab.url = result.url
        tab.method = result.method
        let parsedHeaders = result.headers.map { KeyValuePair(key: $0.0, value: $0.1) }
        tab.headers = parsedHeaders.isEmpty ? [KeyValuePair()] : parsedHeaders

        if let body = result.body {
            if let data = body.data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: data)) != nil {
                tab.bodyType = BodyType.json.rawValue
                tab.jsonBody = body
            } else {
                tab.bodyType = BodyType.raw.rawValue
                tab.rawBody = body
            }
        } else {
            tab.bodyType = BodyType.none.rawValue
        }

        switch result.auth {
        case .basicAuth(let username, let password):
            tab.authMethod = AuthMethod.basic.rawValue
            tab.basicUsername = username
            tab.basicPassword = password
        case .digestAuth(let username, let password):
            tab.authMethod = AuthMethod.digest.rawValue
            tab.digestUsername = username
            tab.digestPassword = password
        default:
            break
        }

        markDirty(tab)
        curlImportText = ""
    }

    private func saveCurrentRequest() {
        guard let tab = activeTab else { return }
        let saved = SavedRequestModel(
            name: saveRequestName,
            method: tab.method,
            url: tab.url
        )
        saved.tagList = saveRequestTags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        saved.headers = tab.headers
        saved.bodyType = tab.bodyType

        let bodyTypeEnum = BodyType(rawValue: tab.bodyType) ?? .none
        switch bodyTypeEnum {
        case .none: break
        case .json: saved.body = .json(tab.jsonBody)
        case .formData: saved.body = .formData(tab.formDataPairs)
        case .raw: saved.body = .raw(tab.rawBody)
        case .graphql: saved.body = .graphql(query: tab.graphqlQuery, variables: tab.graphqlVariables)
        case .multipart: saved.body = .multipart(tab.multipartParts)
        // Saved requests persist the file bytes (the path may not exist on other devices).
        case .binary: saved.body = (try? BinaryBodyFile.load(path: tab.binaryFilePath)).map { .binary($0) }
        }

        saved.preScript = tab.preScript.isEmpty ? nil : tab.preScript
        saved.postScript = tab.postScript.isEmpty ? nil : tab.postScript
        saved.rewriteScript = tab.rewriteScript.isEmpty ? nil : tab.rewriteScript

        modelContext.insert(saved)

        tab.displayName = saveRequestName
        tab.linkedSavedRequestID = saved.id
        tab.isDirty = false
    }

    private func restoreFromSaved(_ item: SavedRequestModel) {
        // If a tab is already opened for this saved request, just activate it.
        if let existing = tabs.first(where: { $0.linkedSavedRequestID == item.id }) {
            selectTab(existing)
            return
        }

        // Otherwise open a new tab with the saved content.
        let tab = OpenTabModel()
        tab.sortIndex = (tabs.map { $0.sortIndex }.max() ?? -1) + 1
        tab.displayName = item.name
        tab.linkedSavedRequestID = item.id
        tab.method = item.method
        tab.url = item.url
        tab.headers = item.headers.isEmpty ? [KeyValuePair()] : item.headers

        if let bt = item.bodyType {
            tab.bodyType = bt
        } else {
            tab.bodyType = BodyType.none.rawValue
        }

        if let body = item.body {
            switch body {
            case .json(let json):
                tab.jsonBody = json
                tab.bodyType = BodyType.json.rawValue
            case .formData(let pairs):
                tab.formDataPairs = pairs
                tab.bodyType = BodyType.formData.rawValue
            case .raw(let raw):
                tab.rawBody = raw
                tab.bodyType = BodyType.raw.rawValue
            case .binary(let data):
                tab.restoreBinaryBody(data)
            case .multipart(let parts):
                tab.multipartParts = parts
                tab.bodyType = BodyType.multipart.rawValue
            case .graphql(let query, let variables):
                tab.graphqlQuery = query
                tab.graphqlVariables = variables
                tab.bodyType = BodyType.graphql.rawValue
            }
        }

        tab.preScript = item.preScript ?? ""
        tab.postScript = item.postScript ?? ""
        tab.rewriteScript = item.rewriteScript ?? ""
        tab.isDirty = false

        for t in tabs { t.isActive = false }
        tab.isActive = true
        modelContext.insert(tab)
        activeTabID = tab.id

        response = nil
        errorMessage = nil
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
