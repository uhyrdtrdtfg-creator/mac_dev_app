import SwiftUI

struct ScriptEditorView: View {
    @Binding var preScript: String
    @Binding var postScript: String
    let consoleLogs: [ScriptConsoleOutput]

    @State private var selectedScript: ScriptTab = .preRequest

    enum ScriptTab: String, CaseIterable, Identifiable {
        case preRequest = "Pre-request"
        case postRequest = "Post-request (Tests)"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Script", selection: $selectedScript) {
                ForEach(ScriptTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            // Hint
            Group {
                switch selectedScript {
                case .preRequest:
                    Text("Runs before the request. Access/modify `request.method`, `request.url`, `request.headers`, `request.body`. Use `console.log()` for output.")
                case .postRequest:
                    Text("Runs after the response. Access `response.status`, `response.body`, `response.headers`, `response.duration`. Use `assert(condition, name)` for tests.")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            // Code editor
            CodeEditorView(text: selectedScript == .preRequest ? $preScript : $postScript)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
                .frame(minHeight: 120)

            // Console output
            if !consoleLogs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Console")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Spacer()

                        Button {
                            let allLogs = consoleLogs.map(\.message).joined(separator: "\n")
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(allLogs, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .help("Copy all logs")
                    }

                    ScrollView {
                        Text(consoleLogs.map(\.message).joined(separator: "\n"))
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .background(.black.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .frame(maxHeight: 120)
                }
            }
        }
    }
}
