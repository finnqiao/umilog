import Foundation
import GRDB

public final class SightingsRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) { self.database = database }
    
    public func fetchAll() throws -> [WildlifeSighting] {
        try database.read { db in
            try WildlifeSighting.fetchAll(db)
        }
    }
    
    public func fetchByDive(_ diveId: String) throws -> [WildlifeSighting] {
        try database.read { db in
            try WildlifeSighting
                .filter(WildlifeSighting.Columns.diveId == diveId)
                .fetchAll(db)
        }
    }
    
    public func create(_ sighting: WildlifeSighting) throws {
        try database.write { db in
            try sighting.insert(db)
        }
    }
    
    public func getUniqueSpeciesCount() throws -> Int {
        try database.read { db in
            let count = try WildlifeSighting
                .select(WildlifeSighting.Columns.speciesId)
                .distinct()
                .fetchCount(db)
            return count
        }
    }
}
