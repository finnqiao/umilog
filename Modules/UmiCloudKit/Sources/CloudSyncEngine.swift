import Foundation
import CloudKit
import os.log

/// Core CloudKit sync engine handling CKContainer operations
public actor CloudSyncEngine {
    private let container: CKContainer
    private let privateDatabase: CKDatabase
    private let zoneID: CKRecordZone.ID
    private let encryptor: FieldEncryptor?
    private let conflictResolver: ConflictResolver

    private let logger = Logger(subsystem: "app.umilog", category: "CloudSync")

    /// Custom zone name for sync
    private static let zoneName = "UmiLogSync"

    /// Initialize CloudSync engine with a CloudKit container.
    /// - Parameter containerIdentifier: The CloudKit container identifier (e.g., "iCloud.app.umilog")
    /// - Throws: CloudSyncError if CloudKit is not available
    /// - Important: Requires `com.apple.developer.icloud-container-identifiers` and
    ///   `com.apple.developer.icloud-services` entitlements to be configured.
    public init(containerIdentifier: String = "iCloud.app.umilog") throws {
        #if targetEnvironment(simulator)
        // CloudKit is not reliably available on simulator
        throw CloudSyncError.simulatorNotSupported
        #else
        self.container = CKContainer(identifier: containerIdentifier)
        self.privateDatabase = container.privateCloudDatabase
        self.zoneID = CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName)
        self.encryptor = try? FieldEncryptor()
        self.conflictResolver = ConflictResolver()
        #endif
    }

    /// Errors specific to CloudSync
    public enum CloudSyncError: Error, LocalizedError {
        case simulatorNotSupported
        case cloudKitNotAvailable

        public var errorDescription: String? {
            switch self {
            case .simulatorNotSupported:
                return "CloudKit sync is not supported on the iOS Simulator"
            case .cloudKitNotAvailable:
                return "CloudKit is not available. Check iCloud entitlements and container configuration."
            }
        }
    }

    // MARK: - Zone Setup

    /// Create the custom zone if it doesn't exist
    public func setupZone() async throws {
        let zone = CKRecordZone(zoneID: zoneID)
        do {
            _ = try await privateDatabase.save(zone)
            logger.info("Created sync zone: \(Self.zoneName)")
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Zone already exists
            logger.info("Sync zone already exists")
        }
    }

    // MARK: - Push Operations

    /// Push a single record to CloudKit
    public func push<T: SyncableRecord>(_ record: T) async throws -> CKRecord {
        let ckRecord = try record.toCKRecord(zoneID: zoneID, encryptor: encryptor)

        do {
            let savedRecord = try await privateDatabase.save(ckRecord)
            logger.info("Pushed record: \(T.ckRecordType)/\(record.localId)")
            return savedRecord
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Conflict detected - resolve and retry
            if let serverRecord = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord {
                let resolution = conflictResolver.resolve(local: record, remote: serverRecord, decryptor: encryptor)
                switch resolution {
                case .localWins(let winner):
                    // Force push local
                    let retryRecord = try winner.toCKRecord(zoneID: zoneID, encryptor: encryptor)
                    return try await privateDatabase.save(retryRecord)
                case .remoteWins, .merged:
                    // Return server record
                    return serverRecord
                }
            }
            throw error
        }
    }

    /// Push multiple records in a batch
    public func pushBatch<T: SyncableRecord>(_ records: [T]) async throws -> [CKRecord] {
        let ckRecords = try records.map { try $0.toCKRecord(zoneID: zoneID, encryptor: encryptor) }

        let operation = CKModifyRecordsOperation(recordsToSave: ckRecords, recordIDsToDelete: nil)
        operation.savePolicy = .changedKeys
        operation.qualityOfService = .userInitiated

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume(returning: ckRecords)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDatabase.add(operation)
        }
    }

    /// Delete a record from CloudKit
    public func delete(recordType: String, recordId: String) async throws {
        let recordID = CKRecord.ID(recordName: recordId, zoneID: zoneID)
        try await privateDatabase.deleteRecord(withID: recordID)
        logger.info("Deleted record: \(recordType)/\(recordId)")
    }

    // MARK: - Pull Operations

    /// Fetch all records of a type modified since the given date
    public func fetchChanges(recordType: String, since: Date?) async throws -> [CKRecord] {
        var predicate = NSPredicate(value: true)
        if let since = since {
            predicate = NSPredicate(format: "modificationDate > %@", since as NSDate)
        }

        let query = CKQuery(recordType: recordType, predicate: predicate)

        var allRecords: [CKRecord] = []
        var cursor: CKQueryOperation.Cursor? = nil

        repeat {
            let (records, nextCursor) = try await privateDatabase.records(matching: query, inZoneWith: zoneID)
            for recordResult in records {
                if case .success(let record) = recordResult.1 {
                    allRecords.append(record)
                }
            }
            cursor = nextCursor
        } while cursor != nil

        logger.info("Fetched \(allRecords.count) records of type \(recordType)")
        return allRecords
    }

    /// Fetch a specific record by ID
    public func fetch(recordType: String, recordId: String) async throws -> CKRecord? {
        let recordID = CKRecord.ID(recordName: recordId, zoneID: zoneID)
        return try await privateDatabase.record(for: recordID)
    }

    // MARK: - Subscriptions

    /// Subscribe to changes for a record type
    public func subscribeToChanges(recordType: String) async throws {
        let subscriptionID = "changes-\(recordType)"
        let predicate = NSPredicate(value: true)

        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )

        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo

        try await privateDatabase.save(subscription)
        logger.info("Subscribed to changes for \(recordType)")
    }

    // MARK: - Account Status

    /// Check if iCloud is available
    public func checkAccountStatus() async throws -> CKAccountStatus {
        return try await container.accountStatus()
    }
}
