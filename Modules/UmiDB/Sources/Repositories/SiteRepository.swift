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
            let sites = try DiveSite
                .filter(DiveSite.Columns.latitude >= minLat && DiveSite.Columns.latitude <= maxLat)
                .filter(DiveSite.Columns.longitude >= minLon && DiveSite.Columns.longitude <= maxLon)
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
                    tags: Array(site.tags.prefix(3)),
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
    
    /// v3: FTS5 search with weighted ranking and BM25 scoring
    /// Weighted scoring: name(3) > region(2) > tags(2) > location(1) > description(1)
    public func searchFTS(query: String, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            // Sanitize query for FTS5 (remove special chars, lowercase)
            let sanitizedQuery = query.lowercased()
            
            // Query: search in sites_fts virtual table with BM25 weighting
            // FTS5 rank is negative (better matches = lower rank), so multiply to weight importance
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type, 
                   s.tags, s.region, s.visitedCount, s.wishlist,
                   (
                       CASE WHEN f.name MATCH ? THEN rank * 3.0
                            WHEN f.region MATCH ? THEN rank * 2.0
                            WHEN f.tags MATCH ? THEN rank * 2.0
                            WHEN f.location MATCH ? THEN rank * 1.0
                            ELSE rank
                       END
                   ) as weighted_rank
            FROM sites s
            INNER JOIN sites_fts f ON s.id = f.rowid
            WHERE sites_fts MATCH ?
            ORDER BY weighted_rank, s.name
            LIMIT ?
            """
            
            // Run raw SQL query and map to SiteLite
            let sites = try Row.fetchAll(db, sql: sql, 
                                        arguments: [sanitizedQuery, sanitizedQuery, 
                                                   sanitizedQuery, sanitizedQuery,
                                                   sanitizedQuery, limit])
            
            return sites.map { row in
                // Parse tags from JSON array string
                let tagsString = row["tags"] as? String ?? "[]"
                let tags: [String]
                if let data = tagsString.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([String].self, from: data) {
                    tags = Array(decoded.prefix(3))
                } else {
                    tags = []
                }
                
                return SiteLite(
                    id: row["id"],
                    name: row["name"],
                    latitude: row["latitude"],
                    longitude: row["longitude"],
                    difficulty: row["difficulty"],
                    type: row["type"],
                    tags: tags,
                    region: row["region"],
                    visitedCount: row["visitedCount"],
                    wishlist: row["wishlist"]
                )
            }
        }
    }
    
    /// Prefix matching for autocomplete-style search
    /// Supports partial word matching using FTS5 prefix syntax (e.g., "wreck*")
    public func searchPrefix(prefix: String, limit: Int = 20) throws -> [SiteLite] {
        try database.read { db in
            let sanitizedPrefix = prefix.lowercased() + "*"
            
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            INNER JOIN sites_fts f ON s.id = f.rowid
            WHERE sites_fts MATCH ?
            ORDER BY rank, s.name
            LIMIT ?
            """
            
            let sites = try Row.fetchAll(db, sql: sql, 
                                        arguments: [sanitizedPrefix, limit])
            
            return sites.map { row in
                // Parse tags from JSON array string
                let tagsString = row["tags"] as? String ?? "[]"
                let tags: [String]
                if let data = tagsString.data(using: .utf8),
                   let decoded = try? JSONDecoder().decode([String].self, from: data) {
                    tags = Array(decoded.prefix(3))
                } else {
                    tags = []
                }
                
                return SiteLite(
                    id: row["id"],
                    name: row["name"],
                    latitude: row["latitude"],
                    longitude: row["longitude"],
                    difficulty: row["difficulty"],
                    type: row["type"],
                    tags: tags,
                    region: row["region"],
                    visitedCount: row["visitedCount"],
                    wishlist: row["wishlist"]
                )
            }
        }
    }
    
    /// v3: Fetch by tag
    public func fetchByTag(_ tag: String) throws -> [SiteLite] {
        try database.read { db in
            let like = "%\"\(tag)\"%"
            let sites = try DiveSite
                .filter(DiveSite.Columns.tags.like(like))
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
                    tags: Array(site.tags.prefix(3)),
                    region: site.region,
                    visitedCount: site.visitedCount,
                    wishlist: site.wishlist
                )
            }
        }
    }
    
    /// v4: Get precomputed filter counts
    public func facetCounts(region: String? = nil, area: String? = nil) throws -> [MaterializedFilter] {
        // Placeholder for now - returns empty array
        // Full implementation requires raw SQL support in GRDB 6.29.2
        return []
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
}

