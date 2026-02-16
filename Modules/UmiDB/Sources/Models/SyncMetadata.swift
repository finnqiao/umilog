import Foundation
import GRDB

/// Tracks sync status for each syncable record
public struct SyncMetadata: Codable, Identifiable {
    public let id: String
    public let recordType: String
    public let localRecordId: String
    public var ckRecordId: String?
    public var ckSystemFields: Data?
    public var syncStatus: SyncStatus
    public var lastSyncedAt: Date?
    public var localUpdatedAt: Date
    public var errorMessage: String?
    public var retryCount: Int

    public enum SyncStatus: String, Codable {
        case pending
        case synced
        case conflict
        case error
    }

    public init(
        id: String = UUID().uuidString,
        recordType: String,
        localRecordId: String,
        ckRecordId: String? = nil,
        ckSystemFields: Data? = nil,
        syncStatus: SyncStatus = .pending,
        lastSyncedAt: Date? = nil,
        localUpdatedAt: Date = Date(),
        errorMessage: String? = nil,
        retryCount: Int = 0
    ) {
        self.id = id
        self.recordType = recordType
        self.localRecordId = localRecordId
        self.ckRecordId = ckRecordId
        self.ckSystemFields = ckSystemFields
        self.syncStatus = syncStatus
        self.lastSyncedAt = lastSyncedAt
        self.localUpdatedAt = localUpdatedAt
        self.errorMessage = errorMessage
        self.retryCount = retryCount
    }

    enum CodingKeys: String, CodingKey {
        case id
        case recordType = "record_type"
        case localRecordId = "local_record_id"
        case ckRecordId = "ck_record_id"
        case ckSystemFields = "ck_system_fields"
        case syncStatus = "sync_status"
        case lastSyncedAt = "last_synced_at"
        case localUpdatedAt = "local_updated_at"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
    }
}

// MARK: - GRDB
extension SyncMetadata: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sync_metadata"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let recordType = Column(CodingKeys.recordType)
        static let localRecordId = Column(CodingKeys.localRecordId)
        static let ckRecordId = Column(CodingKeys.ckRecordId)
        static let ckSystemFields = Column(CodingKeys.ckSystemFields)
        static let syncStatus = Column(CodingKeys.syncStatus)
        static let lastSyncedAt = Column(CodingKeys.lastSyncedAt)
        static let localUpdatedAt = Column(CodingKeys.localUpdatedAt)
        static let errorMessage = Column(CodingKeys.errorMessage)
        static let retryCount = Column(CodingKeys.retryCount)
    }
}
