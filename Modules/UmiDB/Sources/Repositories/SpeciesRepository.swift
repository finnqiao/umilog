import Foundation
import GRDB

public struct SpeciesCategorySummary: Identifiable, Hashable {
    public let id: String
    public let category: WildlifeSpecies.Category
    public let speciesCount: Int

    public init(category: WildlifeSpecies.Category, speciesCount: Int) {
        self.id = category.rawValue
        self.category = category
        self.speciesCount = speciesCount
    }
}

public struct SpeciesFamilySummary: Identifiable, Hashable {
    public let id: String
    public let family: SpeciesFamily
    public let speciesCount: Int

    public init(family: SpeciesFamily, speciesCount: Int) {
        self.id = family.id
        self.family = family
        self.speciesCount = speciesCount
    }
}

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

    /// Summary counts by category (for browsing UI)
    public func fetchCategorySummaries() throws -> [SpeciesCategorySummary] {
        try database.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT category, COUNT(*) AS count FROM wildlife_species GROUP BY category"
            )
            var countByCategory: [WildlifeSpecies.Category: Int] = [:]
            for row in rows {
                guard let raw = row["category"] as? String,
                      let category = WildlifeSpecies.Category(rawValue: raw) else {
                    continue
                }
                countByCategory[category] = row["count"] as? Int ?? 0
            }

            return WildlifeSpecies.Category.allCases.map { category in
                SpeciesCategorySummary(category: category, speciesCount: countByCategory[category] ?? 0)
            }
        }
    }

    /// Summary counts by family (for browsing UI)
    public func fetchFamilySummaries(category: WildlifeSpecies.Category? = nil) throws -> [SpeciesFamilySummary] {
        try database.read { db in
            let sql: String
            var arguments: [DatabaseValueConvertible] = []
            if let category {
                sql = """
                SELECT f.id, f.name, f.scientific_name, f.category, f.worms_aphia_id, f.gbif_key,
                       COUNT(s.id) AS species_count
                FROM species_families f
                LEFT JOIN wildlife_species s ON s.family_id = f.id
                WHERE f.category = ?
                GROUP BY f.id
                ORDER BY f.name
                """
                arguments = [category.rawValue]
            } else {
                sql = """
                SELECT f.id, f.name, f.scientific_name, f.category, f.worms_aphia_id, f.gbif_key,
                       COUNT(s.id) AS species_count
                FROM species_families f
                LEFT JOIN wildlife_species s ON s.family_id = f.id
                GROUP BY f.id
                ORDER BY f.name
                """
            }

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
            return rows.compactMap { row in
                guard let id = row["id"] as? String,
                      let name = row["name"] as? String,
                      let scientificName = row["scientific_name"] as? String,
                      let categoryRaw = row["category"] as? String,
                      let category = WildlifeSpecies.Category(rawValue: categoryRaw) else {
                    return nil
                }

                let family = SpeciesFamily(
                    id: id,
                    name: name,
                    scientificName: scientificName,
                    category: category,
                    wormsAphiaId: row["worms_aphia_id"] as? Int,
                    gbifKey: row["gbif_key"] as? Int
                )
                let speciesCount = row["species_count"] as? Int ?? 0
                return SpeciesFamilySummary(family: family, speciesCount: speciesCount)
            }
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
