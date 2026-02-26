import Foundation
import GRDB
import UmiDB

/// Observes database changes and queues them for CloudKit sync
public final class DatabaseChangeObserver: TransactionObserver {
    private let syncQueue: SyncQueueManager
    private var pendingChanges: [PendingChange] = []

    /// Tables to observe for sync
    private let observedTables: Set<String> = [
        DiveLog.databaseTableName,
        WildlifeSighting.databaseTableName,
        SightingPhoto.databaseTableName,
        Certification.databaseTableName,
        UserSiteState.databaseTableName,
        Trip.databaseTableName,
        TripSite.databaseTableName
    ]

    public init(syncQueue: SyncQueueManager) {
        self.syncQueue = syncQueue
    }

    // MARK: - TransactionObserver

    public func observes(eventsOfKind eventKind: DatabaseEventKind) -> Bool {
        switch eventKind {
        case .insert(let tableName), .delete(let tableName):
            return observedTables.contains(tableName)
        case .update(let tableName, _):
            return observedTables.contains(tableName)
        }
    }

    public func databaseDidChange(with event: DatabaseEvent) {
        let change = PendingChange(
            tableName: event.tableName,
            rowId: event.rowID,
            kind: event.kind
        )
        pendingChanges.append(change)
    }

    public func databaseDidCommit(_ db: Database) {
        // Process all pending changes
        let changes = pendingChanges
        pendingChanges = []

        Task {
            await processChanges(changes, db: db)
        }
    }

    public func databaseDidRollback(_ db: Database) {
        pendingChanges = []
    }

    // MARK: - Private

    private func processChanges(_ changes: [PendingChange], db: Database) async {
        for change in changes {
            let operation: SyncOperation
            switch change.kind {
            case .insert:
                operation = .create
            case .update:
                operation = .update
            case .delete:
                operation = .delete
            }

            // Get the record ID for this rowid
            if let recordId = try? fetchRecordId(tableName: change.tableName, rowId: change.rowId, db: db) {
                await syncQueue.enqueue(
                    operation: operation,
                    recordType: change.tableName,
                    localId: recordId
                )
            }
        }
    }

    private func fetchRecordId(tableName: String, rowId: Int64, db: Database) throws -> String? {
        let row = try Row.fetchOne(db, sql: "SELECT id FROM \(tableName) WHERE rowid = ?", arguments: [rowId])
        return row?["id"]
    }
}

/// Represents a pending database change
private struct PendingChange {
    let tableName: String
    let rowId: Int64
    let kind: DatabaseEvent.Kind
}

/// Manages the sync queue for pending operations
public actor SyncQueueManager {
    private var queue: [PendingSyncOperation] = []
    private let maxRetries = 3

    public init() {}

    /// Add an operation to the sync queue
    public func enqueue(operation: SyncOperation, recordType: String, localId: String, payload: Data? = nil) {
        let op = PendingSyncOperation(
            recordType: recordType,
            localId: localId,
            operation: operation,
            payload: payload
        )
        queue.append(op)
    }

    /// Get all pending operations
    public func getPendingOperations() -> [PendingSyncOperation] {
        return queue
    }

    /// Remove an operation after successful sync
    public func remove(operationId: String) {
        queue.removeAll { $0.id == operationId }
    }

    /// Mark an operation as failed and retry if under limit
    public func markFailed(operationId: String) -> Bool {
        // For now, just remove failed operations
        // In production, implement retry logic with the SyncQueueItem table
        remove(operationId: operationId)
        return false
    }

    /// Clear all pending operations
    public func clear() {
        queue.removeAll()
    }
}
