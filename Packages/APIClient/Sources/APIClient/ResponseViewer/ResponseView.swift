import SwiftUI
import DevAppCore

enum ResponseTab: String, CaseIterable, Identifiable {
    case body = "Body"; case headers = "Headers"; case cookies = "Cookies"
    var id: String { rawValue }
}

struct ResponseView: View {
    let response: HTTPResponse?; let error: String?
    @State private var selectedTab: ResponseTab = .body

    var body: some View {
        VStack(spacing: 0) {
            if let response {
                HStack { StatusBadge(statusCode: response.statusCode, duration: response.duration, size: response.bodySize); Spacer(); CopyButton(text: String(data: response.body, encoding: .utf8) ?? "") }.padding(12)
                Picker("", selection: $selectedTab) { ForEach(ResponseTab.allCases) { tab in Text(tab.rawValue).tag(tab) } }.pickerStyle(.segmented).padding(.horizontal, 12)
                Divider().padding(.top, 8)
                switch selectedTab {
                case .body:
                    let bodyString = String(data: response.body, encoding: .utf8) ?? ""
                    if isJSON(bodyString) { JSONTreeView(jsonString: bodyString).padding(12) }
                    else { ScrollView { Text(bodyString).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).padding(12) } }
                case .headers:
                    List { ForEach(Array(response.headers.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in HStack { Text(key).font(.system(.body, design: .monospaced)).foregroundStyle(.blue); Spacer(); Text(value).font(.system(.body, design: .monospaced)).foregroundStyle(.secondary) } } }
                case .cookies:
                    if response.cookies.isEmpty { ContentUnavailableView("No Cookies", systemImage: "tray") }
                    else { List(response.cookies, id: \.self) { cookie in Text(cookie).font(.system(.body, design: .monospaced)) } }
                }
            } else if let error {
                ContentUnavailableView { Label("Request Failed", systemImage: "exclamationmark.triangle") } description: { Text(error) }
            } else {
                ContentUnavailableView("No Response", systemImage: "arrow.up.circle", description: Text("Send a request to see the response"))
            }
        }
    }
    private func isJSON(_ s: String) -> Bool { guard let d = s.data(using: .utf8) else { return false }; return (try? JSONSerialization.jsonObject(with: d)) != nil }
}
