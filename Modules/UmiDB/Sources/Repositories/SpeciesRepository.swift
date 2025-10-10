import Foundation
import GRDB

public final class SpeciesRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) { self.database = database }
    
    public func fetchAll() throws -> [WildlifeSpecies] {
        try database.read { db in
            try WildlifeSpecies.order(Column("name")).fetchAll(db)
        }
    }
    
    public func search(_ query: String) throws -> [WildlifeSpecies] {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return try fetchAll() }
        return try database.read { db in
            let like = "%\(query)%"
            return try WildlifeSpecies
                .filter(Column("name").like(like) || Column("scientificName").like(like))
                .order(Column("name"))
                .fetchAll(db)
        }
    }
    
    public func popular(limit: Int = 12) throws -> [WildlifeSpecies] {
        try database.read { db in
            // Get top species ids by sightings count
            struct RowCount: FetchableRecord, Decodable { let speciesId: String; let c: Int }
            let rows = try Row.fetchAll(db, sql: "SELECT speciesId, COUNT(*) AS c FROM sightings GROUP BY speciesId ORDER BY c DESC LIMIT ?", arguments: [limit])
            let ids = rows.compactMap { $0["speciesId"] as? String }
            guard !ids.isEmpty else { return [] }
            let species = try WildlifeSpecies.fetchAll(db, keys: ids)
            // Preserve order from ids
            let dict = Dictionary(uniqueKeysWithValues: species.map { ($0.id, $0) })
            return ids.compactMap { dict[$0] }
        }
    }
}
