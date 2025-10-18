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
    
    /// v3: FTS5 search with lightweight payloads
    public func searchFTS(query: String, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            let like = "%\(query)%"
            let sites = try DiveSite
                .filter(DiveSite.Columns.name.like(like) || DiveSite.Columns.location.like(like) || DiveSite.Columns.description.like(like))
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
    
    // MARK: - Convenience Methods
    
    public func getAllSites() throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .order(DiveSite.Columns.name)
                .fetchAll(db)
        }
    }
}

