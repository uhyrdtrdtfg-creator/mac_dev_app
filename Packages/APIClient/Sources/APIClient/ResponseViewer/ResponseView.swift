import SwiftUI
import DevAppCore

enum ResponseTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case headers = "Headers"
    case cookies = "Cookies"
    case rewrite = "Rewrite"

    var id: String { rawValue }
}

enum BodyDisplayMode: String, CaseIterable, Identifiable {
    case pretty = "Pretty"
    case raw = "Raw"

    var id: String { rawValue }
}

struct ResponseView: View {
    let response: HTTPResponse?
    let error: String?
    let curlCommand: String?
    let onRewrite: ((HTTPResponse) -> Void)?
    @State private var selectedTab: ResponseTab = .body
    @State private var bodyMode: BodyDisplayMode = .pretty
    @State private var showCurl = false
    @State private var rewriteBody = ""
    @State private var rewriteStatusCode = ""
    @State private var rewriteHeaders: [KeyValuePair] = []
    @State private var isRewriteApplied = false

    init(response: HTTPResponse?, error: String?, curlCommand: String? = nil, onRewrite: ((HTTPResponse) -> Void)? = nil) {
        self.response = response
        self.error = error
        self.curlCommand = curlCommand
        self.onRewrite = onRewrite
    }

    var body: some View {
        VStack(spacing: 0) {
            if let response {
                // Status bar
                HStack {
                    StatusBadge(statusCode: response.statusCode, duration: response.duration, size: response.bodySize)

                    if isRewriteApplied {
                        Text("REWRITTEN")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.purple)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    if let curlCommand {
                        Button {
                            showCurl.toggle()
                        } label: {
                            Label("cURL", systemImage: "terminal")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                        .popover(isPresented: $showCurl) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("cURL Command").font(.headline)
                                    Spacer()
                                    CopyButton(text: curlCommand)
                                }
                                ScrollView {
                                    Text(curlCommand)
                                        .font(.system(.caption, design: .monospaced))
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .frame(width: 500, height: 250)
                        }
                    }

                    CopyButton(text: String(data: response.body, encoding: .utf8) ?? "")
                }
                .padding(12)

                // Tabs + controls
                HStack {
                    Picker("Response Tab", selection: $selectedTab) {
                        ForEach(ResponseTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()

                    if selectedTab == .body {
                        Picker("Display Mode", selection: $bodyMode) {
                            ForEach(BodyDisplayMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                    }
                }
                .padding(.horizontal, 12)

                Divider()
                    .padding(.top, 8)

                // Content
                switch selectedTab {
                case .body:
                    bodyView(for: response)

                case .headers:
                    List {
                        ForEach(Array(response.headers.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue)
                                    .lineLimit(nil)
                                Spacer()
                                Text(value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(nil)
                                    .textSelection(.enabled)
                            }
                        }
                    }

                case .cookies:
                    if response.cookies.isEmpty {
                        ContentUnavailableView("No Cookies", systemImage: "tray")
                    } else {
                        List(response.cookies, id: \.self) { cookie in
                            Text(cookie)
                                .font(.system(.body, design: .monospaced))
                                .lineLimit(nil)
                        }
                    }

                case .rewrite:
                    rewriteView(for: response)
                }
            } else if let error {
                ContentUnavailableView {
                    Label("Request Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No Response",
                    systemImage: "arrow.up.circle",
                    description: Text("Send a request to see the response")
                )
            }
        }
        .onChange(of: response) { _, newResponse in
            if let newResponse {
                populateRewriteFields(from: newResponse)
            }
        }
    }

    // MARK: - Body View

    @ViewBuilder
    private func bodyView(for response: HTTPResponse) -> some View {
        let bodyString = String(data: response.body, encoding: .utf8) ?? ""

        switch bodyMode {
        case .pretty:
            if isJSON(bodyString) {
                JSONTreeView(jsonString: bodyString)
                    .padding(12)
            } else {
                rawTextView(bodyString)
            }
        case .raw:
            rawTextView(bodyString)
        }
    }

    private func rawTextView(_ text: String) -> some View {
        ScrollView {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
        }
    }

    // MARK: - Rewrite View

    @ViewBuilder
    private func rewriteView(for response: HTTPResponse) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Instructions
                HStack(spacing: 6) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundStyle(.purple)
                    Text("Modify the response below and click Apply to use the rewritten version.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Status code
                HStack(spacing: 12) {
                    Text("Status Code")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .frame(width: 80, alignment: .trailing)
                    TextField("200", text: $rewriteStatusCode)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(width: 100)
                    Spacer()
                }

                // Headers
                VStack(alignment: .leading, spacing: 6) {
                    Text("Response Headers")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ForEach($rewriteHeaders) { $header in
                        HStack(spacing: 8) {
                            TextField("Header", text: $header.key)
                                .font(.system(.caption, design: .monospaced))
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(.fill.tertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            TextField("Value", text: $header.value)
                                .font(.system(.caption, design: .monospaced))
                                .textFieldStyle(.plain)
                                .padding(6)
                                .background(.fill.tertiary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            Button {
                                rewriteHeaders.removeAll { $0.id == header.id }
                            } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        rewriteHeaders.append(KeyValuePair())
                    } label: {
                        Label("Add Header", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }

                // Body
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Response Body")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Format JSON") {
                            formatRewriteBody()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                    TextEditor(text: $rewriteBody)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(minHeight: 120)
                }

                // Action buttons
                HStack {
                    Spacer()
                    Button("Reset to Original") {
                        populateRewriteFields(from: response)
                        isRewriteApplied = false
                    }
                    .buttonStyle(.bordered)

                    Button("Apply Rewrite") {
                        applyRewrite()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Helpers

    private func populateRewriteFields(from response: HTTPResponse) {
        rewriteBody = String(data: response.body, encoding: .utf8) ?? ""
        rewriteStatusCode = "\(response.statusCode)"
        rewriteHeaders = response.headers.sorted(by: { $0.key < $1.key }).map {
            KeyValuePair(key: $0.key, value: $0.value)
        }

        // Auto-format JSON
        if isJSON(rewriteBody) {
            formatRewriteBody()
        }
    }

    private func formatRewriteBody() {
        guard let data = rewriteBody.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]),
              let formatted = String(data: pretty, encoding: .utf8) else { return }
        rewriteBody = formatted
    }

    private func applyRewrite() {
        let newStatusCode = Int(rewriteStatusCode) ?? response?.statusCode ?? 200
        let newBody = Data(rewriteBody.utf8)
        let newHeaders = Dictionary(uniqueKeysWithValues: rewriteHeaders.filter { !$0.key.isEmpty }.map { ($0.key, $0.value) })

        let rewritten = HTTPResponse(
            statusCode: newStatusCode,
            headers: newHeaders,
            body: newBody,
            duration: response?.duration ?? 0,
            bodySize: newBody.count,
            cookies: response?.cookies ?? []
        )

        isRewriteApplied = true
        onRewrite?(rewritten)
    }

    private func isJSON(_ s: String) -> Bool {
        guard let d = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: d)) != nil
    }
}
