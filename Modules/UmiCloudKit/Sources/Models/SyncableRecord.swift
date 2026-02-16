import Foundation
import CloudKit

/// Protocol for records that can be synced to CloudKit
public protocol SyncableRecord {
    /// The CloudKit record type name
    static var ckRecordType: String { get }

    /// The local record ID (primary key)
    var localId: String { get }

    /// The last update timestamp
    var updatedAt: Date { get }

    /// Fields that should be encrypted before sync
    static var encryptedFields: [String] { get }

    /// Convert to CloudKit record
    func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord

    /// Update from CloudKit record
    mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws
}

/// Default implementation for syncable records
public extension SyncableRecord {
    static var encryptedFields: [String] { [] }
}

/// Sync status for a record
public enum RecordSyncStatus: String, Codable {
    case pending     // Not yet synced
    case syncing     // Currently being synced
    case synced      // Successfully synced
    case conflict    // Has a conflict that needs resolution
    case error       // Failed to sync
}

/// Sync operation type
public enum SyncOperation: String, Codable {
    case create
    case update
    case delete
}

/// Represents a pending sync operation
public struct PendingSyncOperation {
    public let id: String
    public let recordType: String
    public let localId: String
    public let operation: SyncOperation
    public let payload: Data?
    public let createdAt: Date

    public init(
        id: String = UUID().uuidString,
        recordType: String,
        localId: String,
        operation: SyncOperation,
        payload: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recordType = recordType
        self.localId = localId
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
    }
}
