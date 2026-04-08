import SwiftUI
import DevAppCore

enum ResponseTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case headers = "Headers"
    case cookies = "Cookies"

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
    @State private var selectedTab: ResponseTab = .body
    @State private var bodyMode: BodyDisplayMode = .pretty
    @State private var searchText = ""
    @State private var showCurl = false

    init(response: HTTPResponse?, error: String?, curlCommand: String? = nil) {
        self.response = response
        self.error = error
        self.curlCommand = curlCommand
    }

    var body: some View {
        VStack(spacing: 0) {
            if let response {
                // Status bar
                HStack {
                    StatusBadge(statusCode: response.statusCode, duration: response.duration, size: response.bodySize)
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
    }

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

    private func isJSON(_ s: String) -> Bool {
        guard let d = s.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: d)) != nil
    }
}
