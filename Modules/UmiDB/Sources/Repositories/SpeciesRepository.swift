import Foundation
import GRDB

public final class SpeciesRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) { self.database = database }

    // MARK: - Basic Queries

    public func fetchAll() throws -> [WildlifeSpecies] {
        try database.read { db in
            try WildlifeSpecies.order(Column("name")).fetchAll(db)
        }
    }

    public func fetch(id: String) throws -> WildlifeSpecies? {
        try database.read { db in
            try WildlifeSpecies.fetchOne(db, key: id)
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

    /// v5: FTS5 search for species with ranking
    public func searchFTS(query: String, limit: Int = 50) throws -> [WildlifeSpecies] {
        try database.read { db in
            let sanitizedQuery = query.lowercased()

            let sql = """
            SELECT s.* FROM wildlife_species s
            INNER JOIN species_fts f ON s.rowid = f.rowid
            WHERE species_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """

            return try WildlifeSpecies.fetchAll(db, sql: sql, arguments: [sanitizedQuery, limit])
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

    // MARK: - v5: Family/Taxonomy Queries

    /// Fetch all species families
    public func fetchFamilies() throws -> [SpeciesFamily] {
        try database.read { db in
            try SpeciesFamily.order(Column("name")).fetchAll(db)
        }
    }

    /// Fetch families by category
    public func fetchFamilies(category: WildlifeSpecies.Category) throws -> [SpeciesFamily] {
        try database.read { db in
            try SpeciesFamily
                .filter(SpeciesFamily.Columns.category == category.rawValue)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    /// Fetch species by family
    public func fetchByFamily(_ familyId: String) throws -> [WildlifeSpecies] {
        try database.read { db in
            try WildlifeSpecies
                .filter(WildlifeSpecies.Columns.familyId == familyId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    /// Fetch species by category
    public func fetchByCategory(_ category: WildlifeSpecies.Category) throws -> [WildlifeSpecies] {
        try database.read { db in
            try WildlifeSpecies
                .filter(WildlifeSpecies.Columns.category == category.rawValue)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    // MARK: - v5: Site-Species Linkage Queries

    /// Fetch species found at a specific dive site
    public func fetchForSite(_ siteId: String) throws -> [WildlifeSpecies] {
        try database.read { db in
            let sql = """
            SELECT s.* FROM wildlife_species s
            INNER JOIN site_species ss ON s.id = ss.species_id
            WHERE ss.site_id = ?
            ORDER BY
                CASE ss.likelihood
                    WHEN 'common' THEN 1
                    WHEN 'occasional' THEN 2
                    ELSE 3
                END,
                s.name
            """
            return try WildlifeSpecies.fetchAll(db, sql: sql, arguments: [siteId])
        }
    }

    /// Fetch species at a site by likelihood
    public func fetchForSite(_ siteId: String, likelihood: SiteSpeciesLink.Likelihood) throws -> [WildlifeSpecies] {
        try database.read { db in
            let sql = """
            SELECT s.* FROM wildlife_species s
            INNER JOIN site_species ss ON s.id = ss.species_id
            WHERE ss.site_id = ? AND ss.likelihood = ?
            ORDER BY s.name
            """
            return try WildlifeSpecies.fetchAll(db, sql: sql, arguments: [siteId, likelihood.rawValue])
        }
    }

    /// Get species-site links for a site
    public func fetchLinksForSite(_ siteId: String) throws -> [SiteSpeciesLink] {
        try database.read { db in
            try SiteSpeciesLink
                .filter(SiteSpeciesLink.Columns.siteId == siteId)
                .order(SiteSpeciesLink.Columns.likelihood)
                .fetchAll(db)
        }
    }

    /// Get count of species at a site
    public func countSpeciesAtSite(_ siteId: String) throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM site_species WHERE site_id = ?", arguments: [siteId]) ?? 0
        }
    }

    // MARK: - Create/Update

    public func create(_ species: WildlifeSpecies) throws {
        try database.write { db in
            try species.insert(db)
        }
    }

    public func createMany(_ speciesList: [WildlifeSpecies]) throws {
        try database.write { db in
            for species in speciesList {
                try species.insert(db)
            }
        }
    }

    public func createFamilies(_ families: [SpeciesFamily]) throws {
        try database.write { db in
            for family in families {
                try family.insert(db)
            }
        }
    }

    public func createSiteLinks(_ links: [SiteSpeciesLink]) throws {
        try database.write { db in
            for link in links {
                try link.insert(db)
            }
        }
    }

    // MARK: - Counts

    public func count() throws -> Int {
        try database.read { db in
            try WildlifeSpecies.fetchCount(db)
        }
    }

    public func countFamilies() throws -> Int {
        try database.read { db in
            try SpeciesFamily.fetchCount(db)
        }
    }

    public func countSiteLinks() throws -> Int {
        try database.read { db in
            try SiteSpeciesLink.fetchCount(db)
        }
    }
}
