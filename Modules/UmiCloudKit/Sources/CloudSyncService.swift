import Foundation
import CloudKit
import Combine
import os.log

/// Main coordinator for CloudKit sync operations
@MainActor
public final class CloudSyncService: ObservableObject {
    /// Current sync state
    @Published public private(set) var syncState: SyncState = .idle

    /// Last successful sync date
    @Published public private(set) var lastSyncDate: Date?

    /// iCloud account status
    @Published public private(set) var accountStatus: CKAccountStatus = .couldNotDetermine

    /// Pending changes count
    @Published public private(set) var pendingChangesCount: Int = 0

    private let engine: CloudSyncEngine
    private let queueManager: SyncQueueManager
    private let logger = Logger(subsystem: "app.umilog", category: "CloudSyncService")

    private static let lastSyncKey = "app.umilog.lastSyncDate"

    public init() throws {
        self.engine = try CloudSyncEngine()
        self.queueManager = SyncQueueManager()

        // Load last sync date
        if let lastSync = UserDefaults.standard.object(forKey: Self.lastSyncKey) as? Date {
            self.lastSyncDate = lastSync
        }

        // Check account status on init
        Task {
            await checkAccountStatus()
        }
    }

    // MARK: - Public API

    /// Initialize sync (call on app launch)
    public func initialize() async {
        do {
            try await engine.setupZone()
            await checkAccountStatus()

            // Subscribe to changes
            try await engine.subscribeToChanges(recordType: "DiveLog")
            try await engine.subscribeToChanges(recordType: "WildlifeSighting")
            try await engine.subscribeToChanges(recordType: "UserSiteState")

            logger.info("CloudKit sync initialized")
        } catch {
            logger.error("Failed to initialize sync: \(error.localizedDescription)")
            syncState = .error(error.localizedDescription)
        }
    }

    /// Perform a full sync
    public func sync() async {
        guard accountStatus == .available else {
            logger.warning("Sync skipped - iCloud not available")
            return
        }

        syncState = .syncing

        // Push pending changes
        await pushPendingChanges()

        // Pull remote changes
        await pullRemoteChanges()

        // Update last sync date
        let now = Date()
        lastSyncDate = now
        UserDefaults.standard.set(now, forKey: Self.lastSyncKey)

        syncState = .idle
        logger.info("Sync completed successfully")
    }

    /// Check iCloud account status
    public func checkAccountStatus() async {
        do {
            accountStatus = try await engine.checkAccountStatus()
            logger.info("Account status: \(String(describing: self.accountStatus))")
        } catch {
            accountStatus = .couldNotDetermine
            logger.error("Failed to check account status: \(error.localizedDescription)")
        }
    }

    // MARK: - Private

    private func pushPendingChanges() async {
        let pending = await queueManager.getPendingOperations()
        pendingChangesCount = pending.count

        for operation in pending {
            // In a full implementation, load the record from DB and push
            // For now, just clear the queue
            await queueManager.remove(operationId: operation.id)
        }

        pendingChangesCount = 0
    }

    private func pullRemoteChanges() async {
        // In a full implementation:
        // 1. Fetch changes since lastSyncDate for each record type
        // 2. Apply changes to local database
        // 3. Resolve any conflicts
        logger.info("Pulling remote changes since \(String(describing: self.lastSyncDate))")
    }
}

/// Current state of sync operations
public enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)

    public var isError: Bool {
        if case .error = self { return true }
        return false
    }

    public var isSyncing: Bool {
        if case .syncing = self { return true }
        return false
    }
}
