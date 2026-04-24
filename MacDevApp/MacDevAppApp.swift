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
    }
}

@main
struct MacDevAppApp: App {
    private let updaterManager = UpdaterManager()
    private let modelContainer: ModelContainer

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
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(modelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)
    }
}
