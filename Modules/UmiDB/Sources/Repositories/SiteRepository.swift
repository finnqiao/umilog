import Foundation
import GRDB

public final class SiteRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) {
        self.database = database
    }
    
    // MARK: - Create
    
    public func create(_ site: DiveSite) throws {
        try database.write { db in
            try site.insert(db)
        }
    }
    
    public func createMany(_ sites: [DiveSite]) throws {
        try database.write { db in
            for site in sites {
                try site.insert(db)
            }
        }
    }
    
    // MARK: - Read
    
    public func fetch(id: String) throws -> DiveSite? {
        try database.read { db in
            try DiveSite.fetchOne(db, key: id)
        }
    }
    
    public func fetchAll() throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
    
    public func fetchInBounds(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .filter(DiveSite.Columns.latitude >= minLat && DiveSite.Columns.latitude <= maxLat)
                .filter(DiveSite.Columns.longitude >= minLon && DiveSite.Columns.longitude <= maxLon)
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
    
    /// v3: Viewport-first with lightweight SiteLite payload and optional filters
    public func fetchInBoundsLite(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                                   filters: SiteFilters = SiteFilters(), limit: Int = 500) throws -> [SiteLite] {
        try database.read { db in
            var query = DiveSite
                .filter(DiveSite.Columns.latitude >= minLat && DiveSite.Columns.latitude <= maxLat)
                .filter(DiveSite.Columns.longitude >= minLon && DiveSite.Columns.longitude <= maxLon)
            
            // Apply difficulty filter if specified
            if !filters.difficulty.isEmpty {
                query = query.filter(DiveSite.Columns.difficulty.collate(.nocase).in(filters.difficulty))
            }
            
            // Apply tag filters (join with site_tags if needed)
            if !filters.tags.isEmpty {
                // TODO: Add tag filtering via site_tags join
                // For now, rely on full-text search
            }
            
            let sites = try query
                .limit(limit)
                .order(DiveSite.Columns.name)
                .fetchAll(db)
            
            return sites.map { site in
                SiteLite(
                    id: site.id,
                    name: site.name,
                    latitude: site.latitude,
                    longitude: site.longitude,
                    difficulty: site.difficulty.rawValue,
                    type: site.type.rawValue,
                    tags: site.tags.prefix(3).map(String.init),
                    region: site.region,
                    visitedCount: site.visitedCount,
                    wishlist: site.wishlist
                )
            }
        }
    }
    
    public func search(query: String) throws -> [DiveSite] {
        try database.read { db in
            let like = "%\(query)%"
            return try DiveSite
                .filter(DiveSite.Columns.name.like(like) || DiveSite.Columns.location.like(like))
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
    
    /// v3: FTS5 search with lightweight payloads
    public func searchFTS(query: String, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            let sql = """
            SELECT DISTINCT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            WHERE s.id IN (
                SELECT rowid FROM sites_fts WHERE sites_fts MATCH ?
            )
            LIMIT ?
            """
            
            let rows = try db.fetch(sql, arguments: [query, limit]) { row in
                row
            }
            
            return rows.compactMap { row in
                SiteLite(
                    id: row[0] as? String ?? "",
                    name: row[1] as? String ?? "",
                    latitude: row[2] as? Double ?? 0,
                    longitude: row[3] as? Double ?? 0,
                    difficulty: row[4] as? String ?? "Intermediate",
                    type: row[5] as? String ?? "Reef",
                    tags: (try? JSONDecoder().decode([String].self, from: (row[6] as? String ?? "[]").data(using: .utf8) ?? Data())) ?? [],
                    region: row[7] as? String ?? "",
                    visitedCount: row[8] as? Int ?? 0,
                    wishlist: row[9] as? Bool ?? false
                )
            }
        }
    }
    
    /// v3: Fetch by tag
    public func fetchByTag(_ tag: String) throws -> [SiteLite] {
        try database.read { db in
            let sql = """
            SELECT DISTINCT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            INNER JOIN site_tags st ON s.id = st.site_id
            WHERE st.tag = ?
            ORDER BY s.name
            """
            
            let rows = try db.fetch(sql, arguments: [tag]) { row in
                row
            }
            
            return rows.compactMap { row in
                SiteLite(
                    id: row[0] as? String ?? "",
                    name: row[1] as? String ?? "",
                    latitude: row[2] as? Double ?? 0,
                    longitude: row[3] as? Double ?? 0,
                    difficulty: row[4] as? String ?? "Intermediate",
                    type: row[5] as? String ?? "Reef",
                    tags: (try? JSONDecoder().decode([String].self, from: (row[6] as? String ?? "[]").data(using: .utf8) ?? Data())) ?? [],
                    region: row[7] as? String ?? "",
                    visitedCount: row[8] as? Int ?? 0,
                    wishlist: row[9] as? Bool ?? false
                )
            }
        }
    }
    
    /// v4: Get precomputed filter counts
    public func facetCounts(region: String? = nil, area: String? = nil) throws -> [MaterializedFilter] {
        try database.read { db in
            let sql: String
            let args: [DatabaseValueConvertible]
            
            if let region = region, let area = area {
                sql = "SELECT region, area, facet, value, count FROM site_filters_materialized WHERE region = ? AND area = ? ORDER BY facet, count DESC"
                args = [region, area]
            } else if let region = region {
                sql = "SELECT region, area, facet, value, count FROM site_filters_materialized WHERE region = ? AND area IS NULL ORDER BY facet, count DESC"
                args = [region]
            } else {
                sql = "SELECT region, area, facet, value, count FROM site_filters_materialized WHERE region IS NULL AND area IS NULL ORDER BY facet, count DESC"
                args = []
            }
            
            return try db.fetch(sql, arguments: args) { row in
                MaterializedFilter(
                    region: row[0] as? String,
                    area: row[1] as? String,
                    facet: row[2] as? String ?? "",
                    value: row[3] as? String ?? "",
                    count: row[4] as? Int ?? 0
                )
            }
        }
    }
    
    public func fetchWishlist() throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .filter(DiveSite.Columns.wishlist == true)
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
    
    public func fetchVisited() throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .filter(DiveSite.Columns.visitedCount > 0)
                .order(DiveSite.Columns.visitedCount.desc)
                .fetchAll(db)
        }
    }
    
    // MARK: - Update
    
    public func update(_ site: DiveSite) throws {
        try database.write { db in
            var updatedSite = site
            try updatedSite.update(db)
        }
    }
    
    public func toggleWishlist(siteId: String) throws {
        try database.write { db in
            guard var site = try DiveSite.fetchOne(db, key: siteId) else { return }
            // Need to reconstruct since fields are let
            let updated = DiveSite(
                id: site.id,
                name: site.name,
                location: site.location,
                latitude: site.latitude,
                longitude: site.longitude,
                region: site.region,
                averageDepth: site.averageDepth,
                maxDepth: site.maxDepth,
                averageTemp: site.averageTemp,
                averageVisibility: site.averageVisibility,
                difficulty: site.difficulty,
                type: site.type,
                description: site.description,
                wishlist: !site.wishlist,
                visitedCount: site.visitedCount,
                tags: site.tags,
                createdAt: site.createdAt
            )
            try updated.update(db)
        }
    }
    
    // MARK: - Delete
    
    public func delete(id: String) throws {
        try database.write { db in
            try DiveSite.deleteOne(db, key: id)
        }
    }
    
    // MARK: - Convenience Methods
    
    public func getAllSites() throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
}

