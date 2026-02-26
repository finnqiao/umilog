import Foundation
import GRDB

public final class DiveProfileRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchByDive(_ diveId: String) throws -> DiveProfile? {
        try database.read { db in
            try DiveProfile
                .filter(DiveProfile.Columns.diveId == diveId)
                .fetchOne(db)
        }
    }

    public func upsert(_ profile: DiveProfile) throws {
        try database.write { db in
            // diveId is unique, so replace existing profile for this dive
            _ = try DiveProfile
                .filter(DiveProfile.Columns.diveId == profile.diveId)
                .deleteAll(db)
            try profile.insert(db)
        }
    }

    public func deleteByDive(_ diveId: String) throws {
        _ = try database.write { db in
            try DiveProfile
                .filter(DiveProfile.Columns.diveId == diveId)
                .deleteAll(db)
        }
    }
}
