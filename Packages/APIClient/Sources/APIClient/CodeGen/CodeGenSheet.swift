import SwiftUI
import DevAppCore

struct CodeGenSheet: View {
    @State var request: CodeGenRequest
    @Environment(\.dismiss) private var dismiss
    @State private var language: CodeGenLanguage = .swiftURLSession
    @State private var curlText = ""
    @State private var curlError: String?

    private var code: String {
        RequestCodeGenerator.generate(language, request: request)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Generate Code").font(.headline)
                Spacer()
                Button("Close") { dismiss() }.buttonStyle(.bordered)
            }

            Picker("Language", selection: $language) {
                ForEach(CodeGenLanguage.allCases) { lang in
                    Text(lang.rawValue).tag(lang)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text(language.displayName).font(.caption).foregroundStyle(.secondary)
                Spacer()
                CopyButton(text: code)
            }

            ScrollView([.vertical, .horizontal]) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))

            DisclosureGroup("From cURL…") {
                VStack(alignment: .leading, spacing: 6) {
                    CodeEditorView(text: $curlText, fontSize: 11)
                        .frame(height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(.separator, lineWidth: 0.5))
                    HStack {
                        if let curlError {
                            Label(curlError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
                        }
                        Spacer()
                        Button("Generate from cURL") {
                            if let parsed = CurlHelper.parse(curlText) {
                                request = CodeGenRequest(curl: parsed)
                                curlError = nil
                            } else {
                                curlError = "Could not parse cURL command"
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(curlText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 4)
            }
            .font(.caption)
        }
        .padding()
        .frame(width: 640, height: 520)
    }
}
