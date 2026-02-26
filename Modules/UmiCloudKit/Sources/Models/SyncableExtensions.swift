import Foundation
import CloudKit
import UmiDB
import UmiCoreKit

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

// MARK: - Certification + SyncableRecord

extension Certification: SyncableRecord {
    public static var ckRecordType: String { "Certification" }

    public var localId: String { id }

    public static var encryptedFields: [String] {
        ["certNumber", "notes", "instructorNumber"]
    }

    public func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record["agency"] = agency.rawValue as CKRecordValue
        record["agencyOther"] = agencyOther as CKRecordValue?
        record["level"] = level as CKRecordValue
        record["certDate"] = certDate as CKRecordValue?
        record["expiryDate"] = expiryDate as CKRecordValue?
        record["instructorName"] = instructorName as CKRecordValue?
        record["divesAtCert"] = divesAtCert as CKRecordValue?
        record["isPrimary"] = isPrimary as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue
        record["updatedAt"] = updatedAt as CKRecordValue

        if let encryptor, let certNumber, !certNumber.isEmpty {
            record["certNumberEncrypted"] = try encryptor.encrypt(certNumber) as CKRecordValue
        } else {
            record["certNumber"] = certNumber as CKRecordValue?
        }

        if let encryptor, let notes, !notes.isEmpty {
            record["notesEncrypted"] = try encryptor.encrypt(notes) as CKRecordValue
        } else {
            record["notes"] = notes as CKRecordValue?
        }

        if let encryptor, let instructorNumber, !instructorNumber.isEmpty {
            record["instructorNumberEncrypted"] = try encryptor.encrypt(instructorNumber) as CKRecordValue
        } else {
            record["instructorNumber"] = instructorNumber as CKRecordValue?
        }

        if let cardImageFront {
            record["cardImageFront"] = cardImageFront as CKRecordValue
            if let url = CertificationCardStorageService.shared.imageURL(forRelativePath: cardImageFront) {
                record["cardFrontAsset"] = CKAsset(fileURL: url)
            }
        }

        if let cardImageBack {
            record["cardImageBack"] = cardImageBack as CKRecordValue
            if let url = CertificationCardStorageService.shared.imageURL(forRelativePath: cardImageBack) {
                record["cardBackAsset"] = CKAsset(fileURL: url)
            }
        }

        return record
    }

    public mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws {
        var certNumberValue = ckRecord["certNumber"] as? String
        var notesValue = ckRecord["notes"] as? String
        var instructorNumberValue = ckRecord["instructorNumber"] as? String

        if let encrypted = ckRecord["certNumberEncrypted"] as? Data, let decryptor {
            certNumberValue = try decryptor.decrypt(encrypted)
        }
        if let encrypted = ckRecord["notesEncrypted"] as? Data, let decryptor {
            notesValue = try decryptor.decrypt(encrypted)
        }
        if let encrypted = ckRecord["instructorNumberEncrypted"] as? Data, let decryptor {
            instructorNumberValue = try decryptor.decrypt(encrypted)
        }

        self = Certification(
            id: ckRecord.recordID.recordName,
            agency: CertAgency(rawValue: ckRecord["agency"] as? String ?? "") ?? .other,
            agencyOther: ckRecord["agencyOther"] as? String,
            level: ckRecord["level"] as? String ?? "Certification",
            certNumber: certNumberValue,
            certDate: ckRecord["certDate"] as? Date,
            expiryDate: ckRecord["expiryDate"] as? Date,
            instructorName: ckRecord["instructorName"] as? String,
            instructorNumber: instructorNumberValue,
            divesAtCert: ckRecord["divesAtCert"] as? Int,
            cardImageFront: ckRecord["cardImageFront"] as? String,
            cardImageBack: ckRecord["cardImageBack"] as? String,
            notes: notesValue,
            isPrimary: ckRecord["isPrimary"] as? Bool ?? false,
            createdAt: ckRecord["createdAt"] as? Date ?? Date(),
            updatedAt: ckRecord["updatedAt"] as? Date ?? Date()
        )
    }
}

// MARK: - SightingPhoto + SyncableRecord

extension SightingPhoto: SyncableRecord {
    public static var ckRecordType: String { "SightingPhoto" }

    public var localId: String { id }

    public var updatedAt: Date { createdAt }

    public static var encryptedFields: [String] { [] }

    public func toCKRecord(zoneID: CKRecordZone.ID, encryptor: FieldEncryptor?) throws -> CKRecord {
        let recordID = CKRecord.ID(recordName: id, zoneID: zoneID)
        let record = CKRecord(recordType: Self.ckRecordType, recordID: recordID)

        record["sightingId"] = sightingId as CKRecordValue
        record["filename"] = filename as CKRecordValue
        record["thumbnailFilename"] = thumbnailFilename as CKRecordValue
        record["width"] = width as CKRecordValue
        record["height"] = height as CKRecordValue
        record["capturedAt"] = capturedAt as CKRecordValue?
        record["latitude"] = latitude as CKRecordValue?
        record["longitude"] = longitude as CKRecordValue?
        record["sortOrder"] = sortOrder as CKRecordValue
        record["createdAt"] = createdAt as CKRecordValue

        if let photoURL = SightingPhotoStorageService.shared.imageURL(forRelativePath: filename) {
            record["photoAsset"] = CKAsset(fileURL: photoURL)
        }

        return record
    }

    public mutating func updateFrom(ckRecord: CKRecord, decryptor: FieldEncryptor?) throws {
        let width = (ckRecord["width"] as? Int) ?? Int((ckRecord["width"] as? Int64) ?? 0)
        let height = (ckRecord["height"] as? Int) ?? Int((ckRecord["height"] as? Int64) ?? 0)
        let sortOrder = (ckRecord["sortOrder"] as? Int) ?? Int((ckRecord["sortOrder"] as? Int64) ?? 0)

        self = SightingPhoto(
            id: ckRecord.recordID.recordName,
            sightingId: ckRecord["sightingId"] as? String ?? "",
            filename: ckRecord["filename"] as? String ?? "",
            thumbnailFilename: ckRecord["thumbnailFilename"] as? String ?? "",
            width: width,
            height: height,
            capturedAt: ckRecord["capturedAt"] as? Date,
            latitude: ckRecord["latitude"] as? Double,
            longitude: ckRecord["longitude"] as? Double,
            sortOrder: sortOrder,
            createdAt: ckRecord["createdAt"] as? Date ?? Date()
        )
    }
}
