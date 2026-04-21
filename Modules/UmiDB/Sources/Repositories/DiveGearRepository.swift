import Foundation
import GRDB

public final class DiveGearRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchLinks(forDive diveId: String) throws -> [DiveGear] {
        try database.read { db in
            try DiveGear
                .filter(DiveGear.Columns.diveId == diveId)
                .fetchAll(db)
        }
    }

    public func fetchGear(forDive diveId: String) throws -> [GearItem] {
        try database.read { db in
            try GearItem
                .joining(required: GearItem.diveGear.filter(DiveGear.Columns.diveId == diveId))
                .order(GearItem.Columns.category.asc)
                .order(GearItem.Columns.name.asc)
                .fetchAll(db)
        }
    }

    public func setGear(forDive diveId: String, gearIds: [String]) throws {
        try database.write { db in
            _ = try DiveGear
                .filter(DiveGear.Columns.diveId == diveId)
                .deleteAll(db)

            let uniqueGearIds = Array(Set(gearIds))
            for gearId in uniqueGearIds {
                let link = DiveGear(diveId: diveId, gearId: gearId)
                try link.insert(db)
            }

            for gearId in uniqueGearIds {
                let count = try DiveGear
                    .filter(DiveGear.Columns.gearId == gearId)
                    .fetchCount(db)
                try db.execute(
                    sql: "UPDATE gear_items SET totalDiveCount = ?, updatedAt = ? WHERE id = ?",
                    arguments: [count, Date(), gearId]
                )
            }
        }
    }
}
