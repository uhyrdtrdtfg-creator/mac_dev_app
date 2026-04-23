import Foundation
import SwiftData
import CloudKit

/// Service for managing iCloud sync operations with SwiftData
@MainActor
@Observable
final class CloudSyncService {
    enum SyncState: Equatable {
        case idle
        case syncing
        case success
        case error(String)
    }

    private(set) var syncState: SyncState = .idle
    private(set) var lastSyncDate: Date?

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Force upload local changes to iCloud
    func pushToCloud() async {
        syncState = .syncing

        do {
            // Save forces pending changes to be written and triggers CloudKit export
            try modelContext.save()

            // Give CloudKit some time to process
            try await Task.sleep(for: .milliseconds(500))

            lastSyncDate = Date()
            syncState = .success

            // Reset to idle after a short delay
            try await Task.sleep(for: .seconds(2))
            syncState = .idle
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    /// Request fresh data from iCloud
    func pullFromCloud() async {
        syncState = .syncing

        do {
            // Check iCloud account status
            let container = CKContainer.default()
            let status = try await container.accountStatus()

            guard status == .available else {
                syncState = .error("iCloud account not available")
                return
            }

            // For SwiftData + CloudKit, we can trigger a refresh by:
            // 1. Touching the persistent store coordinator
            // 2. The system will automatically fetch pending changes

            // Force a save to ensure we're in a clean state
            try modelContext.save()

            // Notify the system to check for remote changes
            NotificationCenter.default.post(
                name: NSNotification.Name("com.apple.coredata.cloudkit.zone.monitor.refresh"),
                object: nil
            )

            // Give CloudKit time to fetch
            try await Task.sleep(for: .seconds(1))

            lastSyncDate = Date()
            syncState = .success

            // Reset to idle after a short delay
            try await Task.sleep(for: .seconds(2))
            syncState = .idle
        } catch {
            syncState = .error(error.localizedDescription)
        }
    }

    /// Full sync: push local changes and pull remote changes
    func syncAll() async {
        await pushToCloud()
        if case .error = syncState { return }
        await pullFromCloud()
    }
}
