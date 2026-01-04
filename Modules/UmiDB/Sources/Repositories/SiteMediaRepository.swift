import Foundation
import GRDB

public final class SiteMediaRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Create

    public func create(_ media: SiteMedia) throws {
        try database.write { db in
            try media.insert(db)
        }
    }

    public func createMany(_ media: [SiteMedia]) throws {
        try database.write { db in
            for item in media {
                try item.insert(db)
            }
        }
    }

    public func upsert(_ media: SiteMedia) throws {
        try database.write { db in
            try media.save(db)
        }
    }

    public func upsertMany(_ media: [SiteMedia]) throws {
        try database.write { db in
            for item in media {
                try item.save(db)
            }
        }
    }

    // MARK: - Read

    public func fetch(id: String) throws -> SiteMedia? {
        try database.read { db in
            try SiteMedia.fetchOne(db, key: id)
        }
    }

    public func fetchMedia(for siteId: String) throws -> SiteMedia? {
        try database.read { db in
            try SiteMedia
                .filter(SiteMedia.Columns.siteId == siteId)
                .filter(SiteMedia.Columns.kind == SiteMedia.MediaKind.photo.rawValue)
                .fetchOne(db)
        }
    }

    public func fetchAllMedia(for siteId: String) throws -> [SiteMedia] {
        try database.read { db in
            try SiteMedia
                .filter(SiteMedia.Columns.siteId == siteId)
                .fetchAll(db)
        }
    }

    public func fetchMediaBatch(siteIds: [String]) throws -> [String: SiteMedia] {
        guard !siteIds.isEmpty else { return [:] }
        return try database.read { db in
            let media = try SiteMedia
                .filter(siteIds.contains(SiteMedia.Columns.siteId))
                .filter(SiteMedia.Columns.kind == SiteMedia.MediaKind.photo.rawValue)
                .fetchAll(db)
            return Dictionary(uniqueKeysWithValues: media.map { ($0.siteId, $0) })
        }
    }

    public func fetchAll() throws -> [SiteMedia] {
        try database.read { db in
            try SiteMedia.fetchAll(db)
        }
    }

    public func count() throws -> Int {
        try database.read { db in
            try SiteMedia.fetchCount(db)
        }
    }

    // MARK: - Delete

    public func delete(id: String) throws {
        try database.write { db in
            _ = try SiteMedia.deleteOne(db, key: id)
        }
    }

    public func deleteAll(for siteId: String) throws {
        try database.write { db in
            _ = try SiteMedia
                .filter(SiteMedia.Columns.siteId == siteId)
                .deleteAll(db)
        }
    }
}
