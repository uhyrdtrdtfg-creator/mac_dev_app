import AppIntents

/// Mirrors the descriptor ids registered in `MacDevAppApp.registerAllTools`.
/// App Intents metadata is extracted at build time, so this list cannot read
/// the runtime registry — KEEP IT IN SYNC MANUALLY when tools are added or removed.
enum ToolID: String, AppEnum {
    // Crypto
    case hashGenerator = "hash-generator"
    case hmacGenerator = "hmac-generator"
    case aesCryptor = "aes-cryptor"
    case rsaCryptor = "rsa-cryptor"
    case jwt = "jwt"
    case certViewer = "cert-viewer"
    case keyDerivation = "key-derivation"
    case totp = "totp"
    // API Client
    case httpClient = "http-client"
    case websocketSSE = "websocket-sse"
    case mockServer = "mock-server"
    // Conversion
    case timestampConverter = "timestamp-converter"
    case urlCodec = "url-codec"
    case base64Codec = "base64-codec"
    case jsonFormatter = "json-formatter"
    case uuidGenerator = "uuid-generator"
    case randomString = "random-string"
    case baseConverter = "base-converter"
    case htmlEntity = "html-entity"
    case stringEscape = "string-escape"
    case stringCase = "string-case"
    case hexAscii = "hex-ascii"
    case lineSort = "line-sort"
    case textAnalyzer = "text-analyzer"
    case loremIpsum = "lorem-ipsum"
    case jsonYaml = "json-yaml"
    case jsonCSV = "json-csv"
    case jsonTOML = "json-toml"
    case markdownPreview = "markdown-preview"
    case textDiff = "text-diff"
    case ocr = "ocr"
    case translator = "translator"
    // Developer
    case regexTester = "regex-tester"
    case cronParser = "cron-parser"
    case colorConverter = "color-converter"
    case sqlFormatter = "sql-formatter"
    case unicodeInspector = "unicode-inspector"
    case compression = "compression"
    case dotenvJSON = "dotenv-json"
    case sqlResult = "sql-result"
    // Generators
    case qrCode = "qr-code"
    case jsonToCode = "json-to-code"
    case imageToolbox = "image-toolbox"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Tool")
    static let caseDisplayRepresentations: [ToolID: DisplayRepresentation] = [
        .hashGenerator: "Hash Generator",
        .hmacGenerator: "HMAC Generator",
        .aesCryptor: "AES Encrypt/Decrypt",
        .rsaCryptor: "RSA Encrypt/Decrypt",
        .jwt: "JWT Decoder",
        .certViewer: "Certificate Viewer",
        .keyDerivation: "Key Derivation",
        .totp: "TOTP / 2FA",
        .httpClient: "HTTP Client",
        .websocketSSE: "WebSocket / SSE",
        .mockServer: "Mock Server",
        .timestampConverter: "Unix Timestamp",
        .urlCodec: "URL Encode/Decode",
        .base64Codec: "Base64 Encode/Decode",
        .jsonFormatter: "JSON Formatter",
        .uuidGenerator: "UUID Generator",
        .randomString: "Random String Generator",
        .baseConverter: "Number Base Converter",
        .htmlEntity: "HTML Entity Encode/Decode",
        .stringEscape: "String Escape/Unescape",
        .stringCase: "String Case Converter",
        .hexAscii: "Hex / ASCII Converter",
        .lineSort: "Line Sort & Deduplicate",
        .textAnalyzer: "Text Analyzer",
        .loremIpsum: "Lorem Ipsum Generator",
        .jsonYaml: "JSON ↔ YAML",
        .jsonCSV: "JSON ↔ CSV",
        .jsonTOML: "JSON ↔ TOML",
        .markdownPreview: "Markdown Preview",
        .textDiff: "Text Diff",
        .ocr: "Image to Text (OCR)",
        .translator: "Translator",
        .regexTester: "Regex Tester",
        .cronParser: "Cron Parser",
        .colorConverter: "Color Converter",
        .sqlFormatter: "SQL Formatter",
        .unicodeInspector: "Unicode Inspector",
        .compression: "Compression",
        .dotenvJSON: ".env ↔ JSON",
        .sqlResult: "SQL Result → CSV/SQL",
        .qrCode: "QR Code",
        .jsonToCode: "JSON → Code",
        .imageToolbox: "Image Toolbox",
    ]
}

struct OpenToolIntent: AppIntent {
    static let title: LocalizedStringResource = "Open Tool"
    static let description = IntentDescription("Opens DevToolkit, navigates to the chosen tool, and optionally pre-fills its input.")
    static let openAppWhenRun = true

    @Parameter(title: "Tool")
    var tool: ToolID

    @Parameter(title: "Input Text")
    var input: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Open \(\.$tool)") {
            \.$input
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        AppCoordinator.shared.activateApp()
        // The route closure is installed by ContentView.onAppear — wait briefly on cold launch.
        for _ in 0..<20 where AppCoordinator.shared.route == nil {
            try await Task.sleep(for: .milliseconds(100))
        }
        guard let route = AppCoordinator.shared.route else { throw ToolIntentError.appNotReady }
        route(input ?? "", tool.rawValue)
        return .result()
    }
}
