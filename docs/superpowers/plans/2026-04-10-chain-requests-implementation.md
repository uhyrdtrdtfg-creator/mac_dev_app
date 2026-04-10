# Chain Requests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add chain request functionality to the HTTP API Client — users can compose ordered sequences of saved requests, execute them serially with pm.environment passing data between steps, and view results in a list overview.

**Architecture:** New SwiftData models (ChainModel, ChainStepModel) reference SavedRequests by UUID. A RequestExecutor extracted from APIClientView handles single-request execution. ChainRunnerService orchestrates serial execution. New ChainListView (sidebar) and ChainEditorView (main area) handle UI.

**Tech Stack:** SwiftUI, SwiftData, JavaScriptCore (existing ScriptEngine), URLSession (existing HTTPClientService)

---

### Task 1: Create Data Models

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Models/ChainModel.swift`
- Create: `Packages/APIClient/Sources/APIClient/Models/ChainRunResult.swift`

- [ ] **Step 1: Create ChainModel.swift**

Create `Packages/APIClient/Sources/APIClient/Models/ChainModel.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class ChainStepModel {
    public var id: UUID
    public var order: Int
    public var savedRequestId: UUID
    @Relationship public var chain: ChainModel?

    public init(order: Int, savedRequestId: UUID) {
        self.id = UUID()
        self.order = order
        self.savedRequestId = savedRequestId
    }
}

@Model
public final class ChainModel {
    public var id: UUID
    public var name: String
    @Relationship(deleteRule: .cascade, inverse: \ChainStepModel.chain)
    public var steps: [ChainStepModel]
    public var createdAt: Date
    public var updatedAt: Date

    public init(name: String) {
        self.id = UUID()
        self.name = name
        self.steps = []
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    public var sortedSteps: [ChainStepModel] {
        steps.sorted { $0.order < $1.order }
    }
}
```

- [ ] **Step 2: Create ChainRunResult.swift**

Create `Packages/APIClient/Sources/APIClient/Models/ChainRunResult.swift`:

```swift
import Foundation

public enum ChainRunStatus: Equatable {
    case idle
    case running(currentStep: Int)
    case completed
    case failed(atStep: Int)
}

public struct StepResult: Identifiable {
    public let id = UUID()
    public let stepOrder: Int
    public let requestName: String
    public let requestMethod: String
    public let requestURL: String
    public let responseStatus: Int?
    public let duration: TimeInterval?
    public let error: String?
    public let httpResponse: HTTPResponse?
    public let consoleLogs: String
}

@MainActor
@Observable
public final class ChainRunResult {
    public var stepResults: [StepResult] = []
    public var startedAt: Date?
    public var finishedAt: Date?
    public var status: ChainRunStatus = .idle

    public init() {}

    public func reset() {
        stepResults = []
        startedAt = nil
        finishedAt = nil
        status = .idle
    }
}
```

- [ ] **Step 3: Verify build**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Models/ChainModel.swift Packages/APIClient/Sources/APIClient/Models/ChainRunResult.swift
git commit -m "feat: add ChainModel and ChainRunResult data models"
```

---

### Task 2: Extract RequestExecutor

Extract the core request execution logic from `APIClientView.sendRequest()` into a reusable static method.

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Networking/RequestExecutor.swift`
- Modify: `Packages/APIClient/Sources/APIClient/APIClientView.swift`

- [ ] **Step 1: Create RequestExecutor.swift**

Create `Packages/APIClient/Sources/APIClient/Networking/RequestExecutor.swift`:

```swift
import Foundation

public struct ExecutionResult: Sendable {
    public let response: HTTPResponse?
    public let error: String?
    public let consoleLogs: [ScriptConsoleOutput]
    public let assertionFailed: Bool
}

public enum RequestExecutor {

    /// Resolve {{variable}} templates with values from pm.environment
    private static func resolveTemplates(_ text: String, env: EnvironmentStore) -> String {
        var result = text
        let pattern = /\{\{([^}]+)\}\}/
        for match in text.matches(of: pattern) {
            let key = String(match.1).trimmingCharacters(in: .whitespaces)
            if let value = env.get(key) {
                result = result.replacingOccurrences(of: String(match.0), with: value)
            }
        }
        return result
    }

    public static func execute(
        method: HTTPMethod,
        url: String,
        headers: [KeyValuePair],
        queryParams: [KeyValuePair],
        body: RequestBody?,
        auth: AuthType?,
        preScript: String?,
        postScript: String?,
        rewriteScript: String?
    ) async -> ExecutionResult {
        var consoleLogs: [ScriptConsoleOutput] = []
        var assertionFailed = false

        do {
            var request = try HTTPClientService.buildURLRequest(
                method: method, url: url, headers: headers,
                queryParams: queryParams, body: body, auth: auth
            )

            // Run pre-request script
            if let preScript, !preScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var scriptCtx = ScriptContext(
                    requestMethod: method.rawValue,
                    requestURL: url,
                    requestHeaders: Dictionary(uniqueKeysWithValues: headers.filter(\.isEnabled).map { ($0.key, $0.value) })
                )
                if case .json(let json) = body { scriptCtx.requestBody = json }

                let preResult = ScriptEngine.runPreScriptCompat(preScript, context: scriptCtx)
                consoleLogs.append(contentsOf: preResult.logs)

                let updatedCtx = preResult.context
                let updatedMethod = HTTPMethod(rawValue: updatedCtx.requestMethod) ?? method
                let updatedHeaders = updatedCtx.requestHeaders.map { KeyValuePair(key: $0.key, value: $0.value) }
                let updatedBody: RequestBody? = updatedCtx.requestBody.map { .json($0) } ?? body
                request = try HTTPClientService.buildURLRequest(
                    method: updatedMethod, url: updatedCtx.requestURL,
                    headers: updatedHeaders, queryParams: [],
                    body: updatedBody, auth: nil
                )
            }

            // Resolve {{variable}} templates AFTER pre-script
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

            // Send
            let httpResponse = try await HTTPClientService.send(request)

            // Run post-request script
            if let postScript, !postScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

                // Check for assertion failures
                if postLogs.contains(where: { $0.message.hasPrefix("FAIL:") }) {
                    assertionFailed = true
                }
            }

            // Run rewrite script
            var finalResponse = httpResponse
            if let rewriteScript, !rewriteScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let bodyString = String(data: httpResponse.body, encoding: .utf8) ?? ""
                let rwCtx = ScriptContext(
                    requestMethod: method.rawValue,
                    requestURL: url,
                    requestHeaders: [:],
                    responseStatus: httpResponse.statusCode,
                    responseBody: bodyString,
                    responseHeaders: httpResponse.headers,
                    responseDuration: httpResponse.duration
                )
                let rwResult = ScriptEngine.runRewriteScript(rewriteScript, context: rwCtx)
                consoleLogs.append(contentsOf: rwResult.logs)

                let newStatus = rwResult.context.responseStatus ?? httpResponse.statusCode
                let newBody = Data((rwResult.context.responseBody ?? bodyString).utf8)
                let newHeaders = rwResult.context.responseHeaders ?? httpResponse.headers
                finalResponse = HTTPResponse(
                    statusCode: newStatus,
                    headers: newHeaders,
                    body: newBody,
                    duration: httpResponse.duration,
                    bodySize: newBody.count,
                    cookies: httpResponse.cookies
                )
            }

            return ExecutionResult(
                response: finalResponse,
                error: nil,
                consoleLogs: consoleLogs,
                assertionFailed: assertionFailed
            )

        } catch {
            return ExecutionResult(
                response: nil,
                error: error.localizedDescription,
                consoleLogs: consoleLogs,
                assertionFailed: false
            )
        }
    }
}
```

- [ ] **Step 2: Refactor APIClientView.sendRequest() to use RequestExecutor**

In `Packages/APIClient/Sources/APIClient/APIClientView.swift`, replace the `sendRequest()` method (lines 191-342) with:

```swift
    private func sendRequest() {
        isSending = true
        response = nil
        errorMessage = nil
        lastCurlCommand = nil
        consoleLogs = []
        rewriteScriptLogs = []

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
            let result = await RequestExecutor.execute(
                method: method,
                url: url,
                headers: headers,
                queryParams: queryParams,
                body: currentBody,
                auth: currentAuth,
                preScript: preScript.isEmpty ? nil : preScript,
                postScript: postScript.isEmpty ? nil : postScript,
                rewriteScript: rewriteScript.isEmpty ? nil : rewriteScript
            )

            consoleLogs = result.consoleLogs
            if let resp = result.response {
                response = resp
                saveToHistory(resp)
            }
            if let err = result.error {
                errorMessage = err
            }
            isSending = false
        }
    }
```

Also remove the now-unused `resolveTemplates` method (lines 503-515) and `sha256Hex` method (lines 344-354) from APIClientView since they are no longer needed there. (The resolveTemplates logic is now in RequestExecutor. The sha256Hex debug logging was specific to the old inline implementation and is not carried over.)

- [ ] **Step 3: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Networking/RequestExecutor.swift Packages/APIClient/Sources/APIClient/APIClientView.swift
git commit -m "refactor: extract RequestExecutor from APIClientView.sendRequest()"
```

---

### Task 3: Create ChainRunnerService

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Chain/ChainRunnerService.swift`

- [ ] **Step 1: Create ChainRunnerService.swift**

Create `Packages/APIClient/Sources/APIClient/Chain/ChainRunnerService.swift`:

```swift
import Foundation
import SwiftData

@MainActor
public final class ChainRunnerService {

    public static func run(
        chain: ChainModel,
        savedRequests: [SavedRequestModel],
        result: ChainRunResult
    ) async {
        result.reset()
        result.startedAt = Date()

        // Clear environment for a clean chain execution
        ScriptEngine.setEnvironment([:])

        let sortedSteps = chain.sortedSteps

        for (index, step) in sortedSteps.enumerated() {
            result.status = .running(currentStep: index)

            // Find the saved request
            guard let savedRequest = savedRequests.first(where: { $0.id == step.savedRequestId }) else {
                let stepResult = StepResult(
                    stepOrder: index,
                    requestName: "(deleted)",
                    requestMethod: "?",
                    requestURL: "?",
                    responseStatus: nil,
                    duration: nil,
                    error: "Saved request not found (may have been deleted)",
                    httpResponse: nil,
                    consoleLogs: ""
                )
                result.stepResults.append(stepResult)
                result.status = .failed(atStep: index)
                result.finishedAt = Date()
                return
            }

            // Restore request parameters from SavedRequest
            let method = HTTPMethod(rawValue: savedRequest.method) ?? .get
            let headers = savedRequest.headers.isEmpty ? [KeyValuePair()] : savedRequest.headers
            let body = savedRequest.body
            let preScript = savedRequest.preScript
            let postScript = savedRequest.postScript
            let rewriteScript = savedRequest.rewriteScript

            // Execute the request
            let execResult = await RequestExecutor.execute(
                method: method,
                url: savedRequest.url,
                headers: headers,
                queryParams: [],
                body: body,
                auth: nil,
                preScript: preScript,
                postScript: postScript,
                rewriteScript: rewriteScript
            )

            let logsText = execResult.consoleLogs.map(\.message).joined(separator: "\n")

            let stepResult = StepResult(
                stepOrder: index,
                requestName: savedRequest.name,
                requestMethod: method.rawValue,
                requestURL: savedRequest.url,
                responseStatus: execResult.response?.statusCode,
                duration: execResult.response?.duration,
                error: execResult.error ?? (execResult.assertionFailed ? "Assertion failed" : nil),
                httpResponse: execResult.response,
                consoleLogs: logsText
            )
            result.stepResults.append(stepResult)

            // Stop on failure
            if execResult.error != nil || execResult.assertionFailed {
                result.status = .failed(atStep: index)
                result.finishedAt = Date()
                return
            }
        }

        result.status = .completed
        result.finishedAt = Date()
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Chain/ChainRunnerService.swift
git commit -m "feat: add ChainRunnerService for serial chain execution"
```

---

### Task 4: Create ChainListView

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Chain/ChainListView.swift`

- [ ] **Step 1: Create ChainListView.swift**

Create `Packages/APIClient/Sources/APIClient/Chain/ChainListView.swift`:

```swift
import SwiftUI
import SwiftData

struct ChainListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChainModel.updatedAt, order: .reverse)
    private var chains: [ChainModel]

    @State private var searchText = ""

    let onSelect: (ChainModel) -> Void

    var filteredChains: [ChainModel] {
        if searchText.isEmpty { return chains }
        let query = searchText.lowercased()
        return chains.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chains")
                    .font(.headline)
                Spacer()
                Button {
                    let chain = ChainModel(name: "New Chain")
                    modelContext.insert(chain)
                    onSelect(chain)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("New Chain")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            TextField("Search...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)

            List {
                ForEach(filteredChains) { chain in
                    Button {
                        onSelect(chain)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chain.name)
                                .font(.body)
                                .lineLimit(1)
                            Text("\(chain.steps.count) steps")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            modelContext.delete(chain)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.plain)
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Chain/ChainListView.swift
git commit -m "feat: add ChainListView sidebar"
```

---

### Task 5: Create ChainEditorView

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Chain/ChainEditorView.swift`

- [ ] **Step 1: Create ChainEditorView.swift**

Create `Packages/APIClient/Sources/APIClient/Chain/ChainEditorView.swift`:

```swift
import SwiftUI
import SwiftData

struct ChainEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var chain: ChainModel

    @Query(sort: \SavedRequestModel.updatedAt, order: .reverse)
    private var allSavedRequests: [SavedRequestModel]

    @State private var runResult = ChainRunResult()
    @State private var showAddStep = false
    @State private var addStepSearch = ""
    @State private var expandedStepId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                TextField("Chain Name", text: $chain.name)
                    .textFieldStyle(.roundedBorder)
                    .font(.headline)
                    .onChange(of: chain.name) { chain.updatedAt = Date() }

                Spacer()

                if case .running = runResult.status {
                    ProgressView()
                        .scaleEffect(0.7)
                        .padding(.trailing, 4)
                }

                Button {
                    Task { await executeChain() }
                } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(chain.steps.isEmpty || runResult.status != .idle && {
                    if case .running = runResult.status { return true }
                    return false
                }())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Steps section
                    stepsSection

                    Divider()
                        .padding(.vertical, 8)

                    // Results section
                    resultsSection
                }
                .padding(12)
            }
        }
    }

    // MARK: - Steps Section

    @ViewBuilder
    private var stepsSection: some View {
        Text("Steps")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.bottom, 4)

        ForEach(chain.sortedSteps) { step in
            stepRow(step)
        }

        Button {
            showAddStep = true
        } label: {
            Label("Add Step", systemImage: "plus")
                .font(.caption)
        }
        .buttonStyle(.bordered)
        .padding(.top, 6)
        .popover(isPresented: $showAddStep) {
            addStepPopover
        }
    }

    private func stepRow(_ step: ChainStepModel) -> some View {
        let savedRequest = allSavedRequests.first { $0.id == step.savedRequestId }
        let methodStr = savedRequest?.method ?? "?"
        let urlStr = savedRequest?.url ?? "(deleted)"
        let nameStr = savedRequest?.name ?? "(deleted)"

        return HStack(spacing: 8) {
            Text("\(step.order + 1).")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .trailing)

            Text(methodStr)
                .font(.caption.weight(.bold).monospaced())
                .foregroundStyle(methodColor(methodStr))
                .frame(width: 50, alignment: .leading)

            Text(nameStr)
                .font(.caption)
                .lineLimit(1)

            Text(urlStr)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            Button { moveStep(step, direction: -1) } label: {
                Image(systemName: "chevron.up")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .disabled(step.order == 0)

            Button { moveStep(step, direction: 1) } label: {
                Image(systemName: "chevron.down")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)
            .disabled(step.order == chain.steps.count - 1)

            Button { removeStep(step) } label: {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.5)))
        .padding(.vertical, 1)
    }

    // MARK: - Add Step Popover

    private var addStepPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Request").font(.headline)
            TextField("Search...", text: $addStepSearch)
                .textFieldStyle(.roundedBorder)

            let filtered = allSavedRequests.filter { req in
                addStepSearch.isEmpty ||
                req.name.localizedCaseInsensitiveContains(addStepSearch) ||
                req.url.localizedCaseInsensitiveContains(addStepSearch)
            }

            List(filtered) { req in
                Button {
                    addStep(savedRequestId: req.id)
                    showAddStep = false
                    addStepSearch = ""
                } label: {
                    HStack {
                        Text(req.method)
                            .font(.caption.weight(.bold).monospaced())
                            .foregroundStyle(methodColor(req.method))
                            .frame(width: 50, alignment: .leading)
                        Text(req.name)
                            .font(.caption)
                        Spacer()
                        Text(req.url)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            .frame(minHeight: 200)
        }
        .padding()
        .frame(width: 450, height: 350)
    }

    // MARK: - Results Section

    @ViewBuilder
    private var resultsSection: some View {
        if runResult.stepResults.isEmpty && runResult.status == .idle {
            Text("Run the chain to see results")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            HStack {
                Text("Results")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let elapsed = totalDuration {
                    Text(String(format: "%.0fms", elapsed * 1000))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 4)

            ForEach(runResult.stepResults) { stepResult in
                resultRow(stepResult)
            }

            if case .running(let currentStep) = runResult.status {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.6)
                    Text("Running step \(currentStep + 1)...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func resultRow(_ stepResult: StepResult) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedStepId = expandedStepId == stepResult.id ? nil : stepResult.id
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: stepResult.error == nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(stepResult.error == nil ? .green : .red)
                        .font(.caption)

                    Text("\(stepResult.stepOrder + 1).")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    Text(stepResult.requestMethod)
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(methodColor(stepResult.requestMethod))

                    Text(stepResult.requestName)
                        .font(.caption)
                        .lineLimit(1)

                    Spacer()

                    if let status = stepResult.responseStatus {
                        Text("\(status)")
                            .font(.caption.weight(.semibold).monospacedDigit())
                            .foregroundStyle(statusColor(status))
                    }

                    if let duration = stepResult.duration {
                        Text(String(format: "%.0fms", duration * 1000))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: expandedStepId == stepResult.id ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 4)

            if let error = stepResult.error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.leading, 24)
                    .padding(.bottom, 4)
            }

            if expandedStepId == stepResult.id {
                expandedDetail(stepResult)
            }
        }
        .padding(.horizontal, 8)
        .background(RoundedRectangle(cornerRadius: 6).fill(.quaternary.opacity(0.3)))
        .padding(.vertical, 1)
    }

    private func expandedDetail(_ stepResult: StepResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("URL: \(stepResult.requestURL)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let resp = stepResult.httpResponse {
                Text("Response Body:")
                    .font(.caption.weight(.semibold))
                let bodyStr = String(data: resp.body, encoding: .utf8) ?? "(binary)"
                ScrollView {
                    Text(bodyStr)
                        .font(.system(.caption2, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 200)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 4).fill(.background))
            }

            if !stepResult.consoleLogs.isEmpty {
                Text("Console:")
                    .font(.caption.weight(.semibold))
                Text(stepResult.consoleLogs)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(.leading, 24)
        .padding(.bottom, 8)
    }

    // MARK: - Actions

    private func addStep(savedRequestId: UUID) {
        let newOrder = chain.steps.count
        let step = ChainStepModel(order: newOrder, savedRequestId: savedRequestId)
        step.chain = chain
        chain.steps.append(step)
        chain.updatedAt = Date()
    }

    private func removeStep(_ step: ChainStepModel) {
        chain.steps.removeAll { $0.id == step.id }
        modelContext.delete(step)
        // Re-order remaining steps
        for (index, s) in chain.sortedSteps.enumerated() {
            s.order = index
        }
        chain.updatedAt = Date()
    }

    private func moveStep(_ step: ChainStepModel, direction: Int) {
        let sorted = chain.sortedSteps
        guard let currentIndex = sorted.firstIndex(where: { $0.id == step.id }) else { return }
        let targetIndex = currentIndex + direction
        guard targetIndex >= 0 && targetIndex < sorted.count else { return }

        sorted[currentIndex].order = targetIndex
        sorted[targetIndex].order = currentIndex
        chain.updatedAt = Date()
    }

    private func executeChain() async {
        runResult.reset()
        await ChainRunnerService.run(
            chain: chain,
            savedRequests: allSavedRequests,
            result: runResult
        )
    }

    // MARK: - Helpers

    private var totalDuration: TimeInterval? {
        guard let start = runResult.startedAt, let end = runResult.finishedAt else { return nil }
        return end.timeIntervalSince(start)
    }

    private func methodColor(_ method: String) -> Color {
        switch method {
        case "GET": .blue
        case "POST": .green
        case "PUT": .orange
        case "PATCH": .purple
        case "DELETE": .red
        default: .secondary
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        case 500...: .red
        default: .secondary
        }
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Chain/ChainEditorView.swift
git commit -m "feat: add ChainEditorView with step management and result display"
```

---

### Task 6: Integrate Chain UI into APIClientView

**Files:**
- Modify: `Packages/APIClient/Sources/APIClient/APIClientView.swift`
- Modify: `Packages/APIClient/Sources/APIClient/APIClientExports.swift`
- Modify: `MacDevApp/MacDevAppApp.swift`

- [ ] **Step 1: Add Chain state and toolbar button to APIClientView**

In `Packages/APIClient/Sources/APIClient/APIClientView.swift`, add these state variables after the existing `@State` declarations (around line 39):

```swift
    @State private var showChains = false
    @State private var selectedChain: ChainModel?
```

- [ ] **Step 2: Add Chains toolbar button**

In the toolbar HStack (after the Import cURL button, before the closing `}` of the HStack around line 131), add:

```swift
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
                    Image(systemName: "link")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Chains")
```

- [ ] **Step 3: Add Chain sidebar and editor to main content**

In the HStack that contains the sidebars (around line 138), after the `if showHistory { ... }` block and before the `VSplitView`, add:

```swift
                if showChains {
                    ChainListView { chain in
                        selectedChain = chain
                    }
                    .frame(width: 250)

                    Divider()
                }
```

Then wrap the existing `VSplitView` in a conditional — if a chain is selected, show the ChainEditorView instead:

Replace the existing `VSplitView { ... }.frame(maxWidth: .infinity)` block with:

```swift
                if let chain = selectedChain {
                    ChainEditorView(chain: chain)
                        .frame(maxWidth: .infinity)
                } else {
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
```

- [ ] **Step 4: Update APIClientExports.swift**

Replace the content of `Packages/APIClient/Sources/APIClient/APIClientExports.swift` with:

```swift
@_exported import DevAppCore

// Re-export SwiftData models for the main app's modelContainer
public typealias _ChainModel = ChainModel
public typealias _ChainStepModel = ChainStepModel
```

- [ ] **Step 5: Register Chain models in MacDevAppApp.swift**

In `MacDevApp/MacDevAppApp.swift`, add `ChainModel.self` and `ChainStepModel.self` to the modelContainer:

```swift
        .modelContainer(for: [
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self,
            ChainModel.self,
            ChainStepModel.self
        ])
```

- [ ] **Step 6: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodegen generate
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -3
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 7: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/APIClientView.swift Packages/APIClient/Sources/APIClient/APIClientExports.swift MacDevApp/MacDevAppApp.swift
git commit -m "feat: integrate chain UI into API Client with toolbar, sidebar, and editor"
```
