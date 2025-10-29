import Foundation
import GRDB

public final class ShopRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) {
        self.database = database
    }
    
    public func count() throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM dive_shops") ?? 0
        }
    }
    
    public func fetchAll() throws -> [DiveShop] {
        try database.read { db in
            try DiveShop
                .order(DiveShop.Columns.name)
                .fetchAll(db)
        }
    }
    
    public func fetchShops(forRegion region: String) throws -> [DiveShop] {
        try database.read { db in
            try DiveShop
                .filter(DiveShop.Columns.region == region)
                .order(DiveShop.Columns.name)
                .fetchAll(db)
        }
    }
    
    public func fetchShops(forArea area: String) throws -> [DiveShop] {
        try database.read { db in
            try DiveShop
                .filter(DiveShop.Columns.area == area)
                .order(DiveShop.Columns.name)
                .fetchAll(db)
        }
    }
    
    public func createMany(_ shops: [DiveShop]) throws {
        guard !shops.isEmpty else { return }
        try database.write { db in
            for shop in shops {
                try shop.insert(db)
            }
        }
    }
    
    public func insertAssociations(_ links: [SiteShopLink]) throws {
        guard !links.isEmpty else { return }
        try database.write { db in
            for link in links {
                try link.insert(db)
            }
        }
    }
}
