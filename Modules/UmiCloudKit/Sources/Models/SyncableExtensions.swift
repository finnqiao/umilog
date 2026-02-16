import Foundation
import CloudKit
import UmiDB

// MARK: - DiveLog + SyncableRecord

extension DiveLog: SyncableRecord {
    public static var ckRecordType: String { "DiveLog" }

    public var localId: String { id }

    public static var encryptedFields: [String] { ["notes"] }

    public func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        // Core fields
        record["siteId"] = siteId as CKRecordValue?
        record["pendingLatitude"] = pendingLatitude as CKRecordValue?
        record["pendingLongitude"] = pendingLongitude as CKRecordValue?
        record["date"] = date as CKRecordValue
        record["startTime"] = startTime as CKRecordValue
        record["endTime"] = endTime as CKRecordValue?
        record["maxDepth"] = maxDepth as CKRecordValue
        record["averageDepth"] = averageDepth as CKRecordValue?
        record["bottomTime"] = bottomTime as CKRecordValue
        record["startPressure"] = startPressure as CKRecordValue
        record["endPressure"] = endPressure as CKRecordValue
        record["temperature"] = temperature as CKRecordValue
        record["visibility"] = visibility as CKRecordValue
        record["current"] = current.rawValue as CKRecordValue
        record["conditions"] = conditions.rawValue as CKRecordValue

        // Encrypted notes field
        if let encryptor = encryptor, !notes.isEmpty {
            let encryptedNotes = try encryptor.encrypt(notes)
            record["notesEncrypted"] = encryptedNotes as CKRecordValue
        } else {
            record["notes"] = notes as CKRecordValue
        }

        // Instructor info
        record["instructorName"] = instructorName as CKRecordValue?
        record["instructorNumber"] = instructorNumber as CKRecordValue?
        record["signed"] = signed as CKRecordValue

        // Timestamps
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }

    public mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws {
        // Create a new instance with updated values
        var notesValue = ckRecord["notes"] as? String ?? ""

        // Decrypt notes if encrypted
        if let encryptedNotes = ckRecord["notesEncrypted"] as? Data,
           let decryptor = decryptor {
            notesValue = try decryptor.decrypt(encryptedNotes)
        }

        self = DiveLog(
            id: ckRecord.recordID.recordName,
            siteId: ckRecord["siteId"] as? String,
            pendingLatitude: ckRecord["pendingLatitude"] as? Double,
            pendingLongitude: ckRecord["pendingLongitude"] as? Double,
            date: ckRecord["date"] as? Date ?? Date(),
            startTime: ckRecord["startTime"] as? Date ?? Date(),
            endTime: ckRecord["endTime"] as? Date,
            maxDepth: ckRecord["maxDepth"] as? Double ?? 0,
            averageDepth: ckRecord["averageDepth"] as? Double,
            bottomTime: ckRecord["bottomTime"] as? Int ?? 0,
            startPressure: ckRecord["startPressure"] as? Int ?? 0,
            endPressure: ckRecord["endPressure"] as? Int ?? 0,
            temperature: ckRecord["temperature"] as? Double ?? 0,
            visibility: ckRecord["visibility"] as? Double ?? 0,
            current: Current(rawValue: ckRecord["current"] as? String ?? "") ?? .none,
            conditions: Conditions(rawValue: ckRecord["conditions"] as? String ?? "") ?? .good,
            notes: notesValue,
            instructorName: ckRecord["instructorName"] as? String,
            instructorNumber: ckRecord["instructorNumber"] as? String,
            signed: ckRecord["signed"] as? Bool ?? false,
            createdAt: ckRecord["createdAt"] as? Date ?? Date(),
            updatedAt: ckRecord["updatedAt"] as? Date ?? Date()
        )
    }
}

// MARK: - WildlifeSighting + SyncableRecord

extension WildlifeSighting: SyncableRecord {
    public static var ckRecordType: String { "WildlifeSighting" }

    public var localId: String { id }

    public var updatedAt: Date { createdAt }  // WildlifeSighting only has createdAt

    public static var encryptedFields: [String] { ["notes"] }

    public func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record["diveId"] = diveId as CKRecordValue
        record["speciesId"] = speciesId as CKRecordValue
        record["count"] = count as CKRecordValue

        // Encrypted notes
        if let encryptor = encryptor, let notes = notes, !notes.isEmpty {
            let encryptedNotes = try encryptor.encrypt(notes)
            record["notesEncrypted"] = encryptedNotes as CKRecordValue
        } else {
            record["notes"] = notes as CKRecordValue?
        }

        record["createdAt"] = createdAt as CKRecordValue

        return record
    }

    public mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws {
        var notesValue: String? = ckRecord["notes"] as? String

        // Decrypt notes if encrypted
        if let encryptedNotes = ckRecord["notesEncrypted"] as? Data,
           let decryptor = decryptor {
            notesValue = try decryptor.decrypt(encryptedNotes)
        }

        self = WildlifeSighting(
            id: ckRecord.recordID.recordName,
            diveId: ckRecord["diveId"] as? String ?? "",
            speciesId: ckRecord["speciesId"] as? String ?? "",
            count: ckRecord["count"] as? Int ?? 1,
            notes: notesValue,
            createdAt: ckRecord["createdAt"] as? Date ?? Date()
        )
    }
}

// MARK: - UserSiteState + SyncableRecord

extension UserSiteState: SyncableRecord {
    public static var ckRecordType: String { "UserSiteState" }

    public var localId: String { siteId }

    public static var encryptedFields: [String] { ["userNotes"] }

    public func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: siteId, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record["siteId"] = siteId as CKRecordValue
        record["isWishlist"] = isWishlist as CKRecordValue
        record["isPlanned"] = isPlanned as CKRecordValue
        record["userRating"] = userRating as CKRecordValue?
        record["lastVisitedAt"] = lastVisitedAt as CKRecordValue?

        // Encrypted notes
        if let encryptor = encryptor, let notes = userNotes, !notes.isEmpty {
            let encryptedNotes = try encryptor.encrypt(notes)
            record["userNotesEncrypted"] = encryptedNotes as CKRecordValue
        } else {
            record["userNotes"] = userNotes as CKRecordValue?
        }

        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        return record
    }

    public mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws {
        var notesValue: String? = ckRecord["userNotes"] as? String

        // Decrypt notes if encrypted
        if let encryptedNotes = ckRecord["userNotesEncrypted"] as? Data,
           let decryptor = decryptor {
            notesValue = try decryptor.decrypt(encryptedNotes)
        }

        self = UserSiteState(
            siteId: ckRecord["siteId"] as? String ?? ckRecord.recordID.recordName,
            isWishlist: ckRecord["isWishlist"] as? Bool ?? false,
            isPlanned: ckRecord["isPlanned"] as? Bool ?? false,
            userNotes: notesValue,
            userRating: ckRecord["userRating"] as? Int,
            lastVisitedAt: ckRecord["lastVisitedAt"] as? Date,
            createdAt: ckRecord["createdAt"] as? Date ?? Date(),
            updatedAt: ckRecord["updatedAt"] as? Date ?? Date()
        )
    }
}
