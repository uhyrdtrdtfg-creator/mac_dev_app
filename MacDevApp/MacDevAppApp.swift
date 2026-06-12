import SwiftUI
import SwiftData
import Sparkle
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@MainActor
final class UpdaterManager {
    private let controller: SPUStandardUpdaterController

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller.updater.automaticallyChecksForUpdates = true
        self.controller.updater.automaticallyDownloadsUpdates = true
        self.controller.updater.updateCheckInterval = 3600 // 1 hour
    }

    func start() {
        do {
            try controller.updater.start()
        } catch {
            print("Sparkle updater failed to start: \(error)")
        }
        // Let the menu-bar "Update" action trigger a manual check.
        AppCoordinator.shared.checkForUpdates = { [controller] in
            controller.updater.checkForUpdates()
        }
    }
}

@main
struct MacDevAppApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private let updaterManager = UpdaterManager()
    private let modelContainer: ModelContainer
    @State private var registry = ToolRegistry()
    @State private var handoff = ToolHandoff()

    init() {
        // Disable smart quotes/dashes globally — critical for a developer tool
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")

        updaterManager.start()

        // Configure SwiftData with iCloud sync for shared models
        let cloudSchema = Schema([
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self,
            ChainModel.self,
            ChainStepModel.self,
            EnvironmentModel.self,
            GlobalVariablesModel.self,
            CookieModel.self
        ])
        // OpenTabModel is device-local (not synced via CloudKit)
        let localSchema = Schema([OpenTabModel.self])
        let fullSchema = Schema([
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self,
            ChainModel.self,
            ChainStepModel.self,
            EnvironmentModel.self,
            GlobalVariablesModel.self,
            CookieModel.self,
            OpenTabModel.self
        ])
        let cloudConfig = ModelConfiguration(
            "Cloud",
            schema: cloudSchema,
            cloudKitDatabase: .automatic
        )
        let localConfig = ModelConfiguration(
            "Local",
            schema: localSchema,
            cloudKitDatabase: .none
        )
        do {
            modelContainer = try ModelContainer(for: fullSchema, configurations: [cloudConfig, localConfig])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Build shared tool state once, before any scene (menu bar, main window) appears.
        let reg = ToolRegistry()
        Self.registerAllTools(into: reg)
        let bus = ToolHandoff()
        Self.configureHandoff(bus, registry: reg)
        _registry = State(initialValue: reg)
        _handoff = State(initialValue: bus)
    }

    var body: some Scene {
        WindowGroup(id: "main") {
            ContentView(registry: registry, handoff: handoff)
        }
        .modelContainer(modelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)

        MenuBarExtra("DevToolkit", systemImage: "hammer.fill") {
            MenuBarView(registry: registry, handoff: handoff)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
        }
    }

    private static func configureHandoff(_ handoff: ToolHandoff, registry: ToolRegistry) {
        handoff.onSelect = { id in registry.selectedToolID = id }
        handoff.destinations = [
            .init(id: "json-formatter", name: "JSON Formatter", icon: "curlybraces"),
            .init(id: "xml-formatter", name: "XML Formatter", icon: "tag"),
            .init(id: "json-to-code", name: "JSON → Code", icon: "chevron.left.forwardslash.chevron.right"),
            .init(id: "plist-converter", name: "Plist Converter", icon: "list.bullet.rectangle"),
            .init(id: "sql-formatter", name: "SQL Formatter", icon: "tablecells.badge.ellipsis"),
            .init(id: "sql-result", name: "SQL Result → CSV/SQL", icon: "tablecells.fill"),
            .init(id: "base64-codec", name: "Base64", icon: "doc.text"),
            .init(id: "url-codec", name: "URL Encode/Decode", icon: "link"),
            .init(id: "hex-ascii", name: "Hex / ASCII", icon: "01.square"),
            .init(id: "html-entity", name: "HTML Entity", icon: "chevron.left.slash.chevron.right"),
            .init(id: "string-escape", name: "String Escape", icon: "textformat"),
            .init(id: "regex-tester", name: "Regex Tester", icon: "asterisk"),
            .init(id: "unicode-inspector", name: "Unicode Inspector", icon: "character.magnify"),
            .init(id: "text-analyzer", name: "Text Analyzer", icon: "text.magnifyingglass"),
        ]
    }

    private static func registerAllTools(into registry: ToolRegistry) {
        registry.registerAll([
            // Crypto
            HashGeneratorView.descriptor,
            HMACGeneratorView.descriptor,
            AESCryptorView.descriptor,
            ChaCha20CryptorView.descriptor,
            TripleDESCryptorView.descriptor,
            RSACryptorView.descriptor,
            JWTView.descriptor,
            CertificateInspectorView.descriptor,
            PEMDERConverterView.descriptor,
            KeyDerivationView.descriptor,
            TOTPView.descriptor,
            // API Client
            APIClientView.descriptor,
            WebSocketClientView.descriptor,
            MockServerView.descriptor,
            // Conversion
            TimestampConverterView.descriptor,
            URLCodecView.descriptor,
            Base64CodecView.descriptor,
            JSONFormatterView.descriptor,
            XMLFormatterView.descriptor,
            UUIDGeneratorView.descriptor,
            RandomStringGeneratorView.descriptor,
            BaseConverterView.descriptor,
            HTMLEntityCodecView.descriptor,
            StringEscaperView.descriptor,
            StringCaseConverterView.descriptor,
            HexAsciiConverterView.descriptor,
            LineSorterView.descriptor,
            TextAnalyzerView.descriptor,
            LoremIpsumGeneratorView.descriptor,
            JSONYamlView.descriptor,
            JSONCSVView.descriptor,
            JSONTOMLView.descriptor,
            PlistConverterView.descriptor,
            MarkdownPreviewView.descriptor,
            TextDiffView.descriptor,
            OCRView.descriptor,
            TranslatorView.descriptor,
            // Developer
            RegexTesterView.descriptor,
            CronParserView.descriptor,
            ColorConverterView.descriptor,
            SQLFormatterView.descriptor,
            UnicodeInspectorView.descriptor,
            CompressionView.descriptor,
            DotenvConverterView.descriptor,
            SQLResultConverterView.descriptor,
            ProcessManagerView.descriptor,
            DNSLookupView.descriptor,
            SubnetCalculatorView.descriptor,
            // Generators
            QRCodeView.descriptor,
            JSONToCodeView.descriptor,
            ImageToolboxView.descriptor,
        ])
    }
}
