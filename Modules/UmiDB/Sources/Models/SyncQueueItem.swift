import Foundation
import GRDB

/// Queued sync operation awaiting execution
public struct SyncQueueItem: Codable, Identifiable {
    public let id: String
    public let operation: Operation
    public let recordType: String
    public let localRecordId: String
    public var payload: Data?
    public let createdAt: Date
    public var attempts: Int
    public var lastAttemptAt: Date?
    public var errorMessage: String?
    public var priority: Int

    public enum Operation: String, Codable {
        case create
        case update
        case delete
    }

    public init(
        id: String = UUID().uuidString,
        operation: Operation,
        recordType: String,
        localRecordId: String,
        payload: Data? = nil,
        createdAt: Date = Date(),
        attempts: Int = 0,
        lastAttemptAt: Date? = nil,
        errorMessage: String? = nil,
        priority: Int = 0
    ) {
        self.id = id
        self.operation = operation
        self.recordType = recordType
        self.localRecordId = localRecordId
        self.payload = payload
        self.createdAt = createdAt
        self.attempts = attempts
        self.lastAttemptAt = lastAttemptAt
        self.errorMessage = errorMessage
        self.priority = priority
    }

    enum CodingKeys: String, CodingKey {
        case id
        case operation
        case recordType = "record_type"
        case localRecordId = "local_record_id"
        case payload
        case createdAt = "created_at"
        case attempts
        case lastAttemptAt = "last_attempt_at"
        case errorMessage = "error_message"
        case priority
    }
}

// MARK: - GRDB
extension SyncQueueItem: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sync_queue"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let operation = Column(CodingKeys.operation)
        static let recordType = Column(CodingKeys.recordType)
        static let localRecordId = Column(CodingKeys.localRecordId)
        static let payload = Column(CodingKeys.payload)
        static let createdAt = Column(CodingKeys.createdAt)
        static let attempts = Column(CodingKeys.attempts)
        static let lastAttemptAt = Column(CodingKeys.lastAttemptAt)
        static let errorMessage = Column(CodingKeys.errorMessage)
        static let priority = Column(CodingKeys.priority)
    }
}
