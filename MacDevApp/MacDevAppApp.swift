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

    init() {
        // Disable smart quotes/dashes globally — critical for a developer tool
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")

        updaterManager.start()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self,
            ChainModel.self,
            ChainStepModel.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .automatic
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)
    }
}
