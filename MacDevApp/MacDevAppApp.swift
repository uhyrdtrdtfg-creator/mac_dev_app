import SwiftUI
import SwiftData
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@main
struct MacDevAppApp: App {
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
