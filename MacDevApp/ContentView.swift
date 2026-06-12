import SwiftUI
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

struct ContentView: View {
    @Bindable var registry: ToolRegistry
    let handoff: ToolHandoff
    @State private var showPalette = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView {
            SidebarView(registry: registry)
        } detail: {
            if let toolID = registry.selectedToolID {
                if toolID == "http-client" || toolID == "markdown-preview" || toolID == "text-diff" || toolID == "websocket-sse" || toolID == "mock-server" || toolID == "regex-tester" || toolID == "unicode-inspector" || toolID == "compression" || toolID == "sql-result" || toolID == "image-toolbox" || toolID == "process-manager" || toolID == "dns-lookup" {
                    toolView(for: toolID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        toolView(for: toolID)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .background(
            Button(action: { showPalette.toggle() }) { EmptyView() }
                .keyboardShortcut("k", modifiers: .command)
                .opacity(0)
        )
        .overlay {
            if showPalette {
                ZStack(alignment: .top) {
                    Color.black.opacity(0.15).ignoresSafeArea()
                        .onTapGesture { showPalette = false }
                    CommandPaletteView(registry: registry, isPresented: $showPalette)
                        .padding(.top, 90)
                }
                .transition(.opacity)
            }
        }
        .environment(\.toolHandoff, handoff)
        .onChange(of: registry.selectedToolID) { _, newValue in
            if let newValue { registry.recordUsage(newValue) }
        }
        .onAppear {
            AppCoordinator.shared.openPalette = {
                showMainWindow(using: openWindow)
                NotificationCenter.default.post(name: .openCommandPalette, object: nil)
            }
            AppCoordinator.shared.route = { text, toolID in
                showMainWindow(using: openWindow)
                handoff.send(text, to: toolID)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openCommandPalette)) { _ in
            showPalette = true
        }
    }

    @ViewBuilder
    private func toolView(for id: String) -> some View {
        switch id {
        case "hash-generator": HashGeneratorView()
        case "hmac-generator": HMACGeneratorView()
        case "aes-cryptor": AESCryptorView()
        case "chacha20": ChaCha20CryptorView()
        case "triple-des": TripleDESCryptorView()
        case "rsa-cryptor": RSACryptorView()
        case "jwt": JWTView()
        case "cert-viewer": CertificateInspectorView()
        case "pem-der": PEMDERConverterView()
        case "key-derivation": KeyDerivationView()
        case "totp": TOTPView()
        case "http-client": APIClientView()
        case "websocket-sse": WebSocketClientView()
        case "mock-server": MockServerView()
        case "timestamp-converter": TimestampConverterView()
        case "url-codec": URLCodecView()
        case "base64-codec": Base64CodecView()
        case "json-formatter": JSONFormatterView()
        case "xml-formatter": XMLFormatterView()
        case "uuid-generator": UUIDGeneratorView()
        case "random-string": RandomStringGeneratorView()
        case "base-converter": BaseConverterView()
        case "html-entity": HTMLEntityCodecView()
        case "string-escape": StringEscaperView()
        case "string-case": StringCaseConverterView()
        case "hex-ascii": HexAsciiConverterView()
        case "line-sort": LineSorterView()
        case "text-analyzer": TextAnalyzerView()
        case "lorem-ipsum": LoremIpsumGeneratorView()
        case "json-yaml": JSONYamlView()
        case "json-csv": JSONCSVView()
        case "json-toml": JSONTOMLView()
        case "plist-converter": PlistConverterView()
        case "markdown-preview": MarkdownPreviewView()
        case "text-diff": TextDiffView()
        case "ocr": OCRView()
        case "translator": TranslatorView()
        case "regex-tester": RegexTesterView()
        case "cron-parser": CronParserView()
        case "color-converter": ColorConverterView()
        case "sql-formatter": SQLFormatterView()
        case "unicode-inspector": UnicodeInspectorView()
        case "compression": CompressionView()
        case "dotenv-json": DotenvConverterView()
        case "sql-result": SQLResultConverterView()
        case "process-manager": ProcessManagerView()
        case "dns-lookup": DNSLookupView()
        case "qr-code": QRCodeView()
        case "json-to-code": JSONToCodeView()
        case "image-toolbox": ImageToolboxView()
        default:
            ContentUnavailableView(
                "Tool Not Found",
                systemImage: "questionmark.circle",
                description: Text("Tool '\(id)' is not available.")
            )
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chevron.left.slash.chevron.right")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 8) {
                Text("DevToolkit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your all-in-one developer companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(width: 200)
                .padding(.vertical, 4)

            HStack(spacing: 32) {
                featureItem(icon: "lock.shield.fill", title: "Crypto", description: "AES, RSA, JWT, Hash, KDF", color: .blue)
                featureItem(icon: "network", title: "API Client", description: "HTTP, WebSocket, Mock", color: .green)
                featureItem(icon: "arrow.2.squarepath", title: "Conversion", description: "Base64, JSON, CSV, YAML", color: .orange)
                featureItem(icon: "hammer.fill", title: "Developer", description: "Regex, Cron, Color, SQL", color: .purple)
                featureItem(icon: "sparkles", title: "Generators", description: "QR Code, JSON → Code", color: .teal)
            }

            Text("Select a tool from the sidebar — or press ⌘K to jump to any tool")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureItem(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color.gradient)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 140)
    }
}
