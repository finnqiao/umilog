import Foundation
import CloudKit

/// Resolves sync conflicts using timestamp-based Last-Write-Wins strategy
public final class ConflictResolver {

    public init() {}

    /// Resolve a conflict between local and remote records
    /// Returns the winning record and whether the local record should be updated
    public func resolve<T: SyncableRecord>(
        local: T,
        remote: CKRecord,
        decryptor: FieldEncryptor?
    ) -> ConflictResolution<T> {
        // Get remote updated timestamp
        guard let remoteUpdatedAt = remote["updatedAt"] as? Date else {
            // If remote has no timestamp, local wins
            return .localWins(local)
        }

        let localUpdatedAt = local.updatedAt

        // Compare timestamps - most recent wins
        if localUpdatedAt > remoteUpdatedAt {
            return .localWins(local)
        } else if remoteUpdatedAt > localUpdatedAt {
            var updatedLocal = local
            do {
                try updatedLocal.updateFrom(ckRecord: remote, decryptor: decryptor)
                return .remoteWins(updatedLocal)
            } catch {
                // If we can't update from remote, keep local
                return .localWins(local)
            }
        } else {
            // Same timestamp - use CloudKit record as tiebreaker
            // (CloudKit's version is considered canonical in case of exact tie)
            var updatedLocal = local
            do {
                try updatedLocal.updateFrom(ckRecord: remote, decryptor: decryptor)
                return .remoteWins(updatedLocal)
            } catch {
                return .localWins(local)
            }
        }
    }

    /// Check if a remote record is newer than the local timestamp
    public func isRemoteNewer(remoteRecord: CKRecord, localUpdatedAt: Date) -> Bool {
        guard let remoteUpdatedAt = remoteRecord["updatedAt"] as? Date else {
            return false
        }
        return remoteUpdatedAt > localUpdatedAt
    }
}

/// Result of conflict resolution
public enum ConflictResolution<T: SyncableRecord> {
    /// Local record is newer - push to cloud
    case localWins(T)

    /// Remote record is newer - update local
    case remoteWins(T)

    /// Both records should be merged (for future complex merge scenarios)
    case merged(T)
}

/// Represents a detected conflict
public struct SyncConflict {
    public let recordType: String
    public let localId: String
    public let localUpdatedAt: Date
    public let remoteUpdatedAt: Date
    public let remoteRecordId: CKRecord.ID

    public init(
        recordType: String,
        localId: String,
        localUpdatedAt: Date,
        remoteUpdatedAt: Date,
        remoteRecordId: CKRecord.ID
    ) {
        self.recordType = recordType
        self.localId = localId
        self.localUpdatedAt = localUpdatedAt
        self.remoteUpdatedAt = remoteUpdatedAt
        self.remoteRecordId = remoteRecordId
    }
}
