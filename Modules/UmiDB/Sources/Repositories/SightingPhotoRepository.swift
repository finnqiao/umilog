import Foundation
import GRDB

public final class SightingPhotoRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchBySighting(_ sightingId: String) throws -> [SightingPhoto] {
        try database.read { db in
            try SightingPhoto
                .filter(SightingPhoto.Columns.sightingId == sightingId)
                .order(SightingPhoto.Columns.sortOrder.asc)
                .order(SightingPhoto.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    public func fetchByDive(_ diveId: String) throws -> [SightingPhoto] {
        try database.read { db in
            try SightingPhoto.fetchAll(
                db,
                sql: """
                SELECT sp.*
                FROM sighting_photos sp
                INNER JOIN sightings s ON s.id = sp.sightingId
                WHERE s.diveId = ?
                ORDER BY sp.sightingId, sp.sortOrder ASC, sp.createdAt ASC
                """,
                arguments: [diveId]
            )
        }
    }

    public func fetchGroupedByDive(_ diveId: String) throws -> [String: [SightingPhoto]] {
        let photos = try fetchByDive(diveId)
        return Dictionary(grouping: photos, by: \.sightingId)
    }

    public func create(_ photo: SightingPhoto) throws {
        try database.write { db in
            try photo.insert(db)
        }
    }

    public func createMany(_ photos: [SightingPhoto]) throws {
        guard !photos.isEmpty else { return }
        try database.write { db in
            for photo in photos {
                try photo.insert(db)
            }
        }
    }

    public func delete(id: String) throws {
        _ = try database.write { db in
            try SightingPhoto.deleteOne(db, key: id)
        }
    }

    public func deleteBySighting(_ sightingId: String) throws {
        try database.write { db in
            _ = try SightingPhoto
                .filter(SightingPhoto.Columns.sightingId == sightingId)
                .deleteAll(db)
        }
    }
}
