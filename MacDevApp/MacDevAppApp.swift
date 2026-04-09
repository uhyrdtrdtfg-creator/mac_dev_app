import SwiftUI
import SwiftData
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@main
struct MacDevAppApp: App {
    init() {
        // Disable smart quotes/dashes globally — critical for a developer tool
        // Prevents " → " " and ' → ' ' and -- → —
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self
        ])
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)
    }
}
