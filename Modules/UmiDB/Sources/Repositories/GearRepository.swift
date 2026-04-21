import Foundation
import GRDB

public final class GearRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func fetchAll(includeRetired: Bool = true) throws -> [GearItem] {
        try database.read { db in
            var request = GearItem
                .order(GearItem.Columns.isActive.desc)
                .order(GearItem.Columns.category.asc)
                .order(GearItem.Columns.name.asc)
            if !includeRetired {
                request = request.filter(GearItem.Columns.isActive == true)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchActive() throws -> [GearItem] {
        try database.read { db in
            try GearItem
                .filter(GearItem.Columns.isActive == true)
                .order(GearItem.Columns.category.asc)
                .order(GearItem.Columns.name.asc)
                .fetchAll(db)
        }
    }

    public func fetch(id: String) throws -> GearItem? {
        try database.read { db in
            try GearItem.fetchOne(db, key: id)
        }
    }

    public func fetchServiceDue(referenceDate: Date = Date()) throws -> [GearItem] {
        try database.read { db in
            try GearItem
                .filter(GearItem.Columns.isActive == true)
                .filter(GearItem.Columns.nextServiceDate != nil)
                .filter(GearItem.Columns.nextServiceDate <= referenceDate)
                .order(GearItem.Columns.nextServiceDate.asc)
                .fetchAll(db)
        }
    }

    public func upsert(_ item: GearItem) throws {
        try database.write { db in
            let normalized = GearItem(
                id: item.id,
                name: item.name,
                category: item.category,
                brand: item.brand,
                model: item.model,
                serialNumber: item.serialNumber,
                purchaseDate: item.purchaseDate,
                lastServiceDate: item.lastServiceDate,
                nextServiceDate: item.nextServiceDate,
                serviceIntervalMonths: item.serviceIntervalMonths,
                notes: item.notes,
                isActive: item.isActive,
                totalDiveCount: item.totalDiveCount,
                createdAt: item.createdAt,
                updatedAt: Date()
            )
            try normalized.save(db)
        }
    }

    public func delete(id: String) throws {
        _ = try database.write { db in
            try GearItem.deleteOne(db, key: id)
        }
    }

    public func refreshDiveCount(for gearId: String) throws {
        try database.write { db in
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
