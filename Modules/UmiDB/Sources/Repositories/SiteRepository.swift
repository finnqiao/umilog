import Foundation
import GRDB

public final class SiteRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) {
        self.database = database
    }

    private func shouldHideLegacySites(_ db: Database) throws -> Bool {
        let sql = """
        SELECT COUNT(*)
        FROM sites
        WHERE id NOT LIKE 'dive_site_%'
          AND id NOT LIKE 'site_%'
        """
        return (try Int.fetchOne(db, sql: sql) ?? 0) > 0
    }

    private func legacyFilterSQL(alias: String? = nil) -> String {
        let prefix = alias.map { "\($0)." } ?? ""
        return "\(prefix)id NOT LIKE 'dive_site_%' AND \(prefix)id NOT LIKE 'site_%'"
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
    
    public func fetchAll(limit: Int? = nil) throws -> [DiveSite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? "WHERE \(legacyFilter)" : ""
            let limitClause = (limit ?? 0) > 0 ? "LIMIT \(limit ?? 0)" : ""
            // Sort by species diversity (popularity proxy), then by name
            let sql = """
            SELECT s.*
            FROM sites s
            LEFT JOIN (
                SELECT site_id, COUNT(*) as species_count
                FROM site_species
                GROUP BY site_id
            ) sc ON s.id = sc.site_id
            \(legacyClause)
            ORDER BY COALESCE(sc.species_count, 0) DESC, s.name
            \(limitClause)
            """
            return try DiveSite.fetchAll(db, sql: sql)
        }
    }

    /// Fetches a ranked subset of sites by popularity proxy.
    public func fetchRanked(limit: Int) throws -> [DiveSite] {
        try fetchAll(limit: limit)
    }

    public func countSites() throws -> Int {
        try database.read { db in
            try Int.fetchOne(db, sql: "SELECT COUNT(*) FROM sites") ?? 0
        }
    }

    public func fetchInBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double,
        limit: Int? = nil
    ) throws -> [DiveSite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let limitClause = (limit ?? 0) > 0 ? "LIMIT ?" : ""
            // Sort by species diversity (popularity proxy), then by name
            let sql = """
            SELECT s.*
            FROM sites s
            LEFT JOIN (
                SELECT site_id, COUNT(*) as species_count
                FROM site_species
                GROUP BY site_id
            ) sc ON s.id = sc.site_id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
              \(legacyClause)
            ORDER BY COALESCE(sc.species_count, 0) DESC, s.name
            \(limitClause)
            """
            var args: [DatabaseValueConvertible] = [minLat, maxLat, minLon, maxLon]
            if let limit, limit > 0 {
                args.append(limit)
            }
            return try DiveSite.fetchAll(db, sql: sql, arguments: StatementArguments(args))
        }
    }
    
    /// v3: Viewport-first with lightweight SiteLite payload and optional filters
    /// Sorted by species diversity (popularity proxy), then by name
    public func fetchInBoundsLite(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                                   filters: SiteFilters = SiteFilters(), limit: Int = 500) throws -> [SiteLite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            // Sort by species diversity (popularity proxy), then by name
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            LEFT JOIN (
                SELECT site_id, COUNT(*) as species_count
                FROM site_species
                GROUP BY site_id
            ) sc ON s.id = sc.site_id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
              \(legacyClause)
            ORDER BY COALESCE(sc.species_count, 0) DESC, s.name
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [minLat, maxLat, minLon, maxLon, limit])
            return rows.map { row in
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
    
    public func search(query: String) throws -> [DiveSite] {
        try database.read { db in
            let like = "%\(query)%"
            var request = DiveSite
                .filter(DiveSite.Columns.name.like(like) || DiveSite.Columns.location.like(like))
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            return try request.fetchAll(db)
        }
    }
    
    /// v3: FTS5 search with weighted ranking and BM25 scoring
    /// Weighted scoring: name(3) > region(2) > tags(2) > location(1) > description(1)
    public func searchFTS(query: String, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
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
            WHERE sites_fts MATCH ?\(legacyClause)
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
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let sanitizedPrefix = prefix.lowercased() + "*"
            
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            INNER JOIN sites_fts f ON s.id = f.rowid
            WHERE sites_fts MATCH ?\(legacyClause)
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
            var request = DiveSite
                .filter(DiveSite.Columns.tags.like(like))
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)
            
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

    /// Fetch sites by type (lightweight payload).
    public func fetchByType(_ type: DiveSite.SiteType, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.type == type.rawValue)
                .order(DiveSite.Columns.name)
                .limit(limit)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

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

    /// Fetch sites by difficulty (lightweight payload).
    public func fetchByDifficulty(_ difficulty: DiveSite.Difficulty, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.difficulty == difficulty.rawValue)
                .order(DiveSite.Columns.name)
                .limit(limit)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

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
            var request = DiveSite
                .filter(DiveSite.Columns.wishlist == true)
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            return try request.fetchAll(db)
        }
    }
    
    public func fetchVisited() throws -> [DiveSite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.visitedCount > 0)
                .order(DiveSite.Columns.visitedCount.desc)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            return try request.fetchAll(db)
        }
    }

    /// v6: Fetch all planned sites
    public func fetchPlanned() throws -> [DiveSite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.isPlanned == true)
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            return try request.fetchAll(db)
        }
    }

    // MARK: - Update
    
    public func update(_ site: DiveSite) throws {
        try database.write { db in
            let updatedSite = site
            try updatedSite.update(db)
        }
    }
    
    public func toggleWishlist(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
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
                isPlanned: site.isPlanned,
                visitedCount: site.visitedCount,
                tags: site.tags,
                createdAt: site.createdAt,
                countryId: site.countryId,
                regionId: site.regionId,
                areaId: site.areaId,
                wikidataId: site.wikidataId,
                osmId: site.osmId
            )
            try updated.update(db)
        }
    }

    /// v6: Toggle planned status for a site
    public func togglePlanned(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
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
                wishlist: site.wishlist,
                isPlanned: !site.isPlanned,
                visitedCount: site.visitedCount,
                tags: site.tags,
                createdAt: site.createdAt,
                countryId: site.countryId,
                regionId: site.regionId,
                areaId: site.areaId,
                wikidataId: site.wikidataId,
                osmId: site.osmId
            )
            try updated.update(db)
        }
    }

    /// v6: Set planned status for a site (without toggling)
    public func setPlanned(siteId: String, isPlanned: Bool) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
            guard site.isPlanned != isPlanned else { return }  // No change needed
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
                wishlist: site.wishlist,
                isPlanned: isPlanned,
                visitedCount: site.visitedCount,
                tags: site.tags,
                createdAt: site.createdAt,
                countryId: site.countryId,
                regionId: site.regionId,
                areaId: site.areaId,
                wikidataId: site.wikidataId,
                osmId: site.osmId
            )
            try updated.update(db)
        }
    }

    // MARK: - Visited Count

    public func incrementVisitedCount(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
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
                wishlist: site.wishlist,
                isPlanned: site.isPlanned,
                visitedCount: site.visitedCount + 1,
                tags: site.tags,
                createdAt: site.createdAt,
                countryId: site.countryId,
                regionId: site.regionId,
                areaId: site.areaId,
                wikidataId: site.wikidataId,
                osmId: site.osmId
            )
            try updated.update(db)
        }
    }

    // MARK: - Delete

    public func delete(id: String) throws {
        _ = try database.write { db in
            try DiveSite.deleteOne(db, key: id)
        }
    }

    // MARK: - v5: Species-based Queries (Bidirectional Filtering)

    /// Fetch sites where a specific species can be found
    public func fetchForSpecies(_ speciesId: String) throws -> [SiteLite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist,
                   ss.likelihood
            FROM sites s
            INNER JOIN site_species ss ON s.id = ss.site_id
            WHERE ss.species_id = ?\(legacyClause)
            ORDER BY
                CASE ss.likelihood
                    WHEN 'common' THEN 1
                    WHEN 'occasional' THEN 2
                    ELSE 3
                END,
                s.name
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [speciesId])
            return rows.map { row in
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

    /// Fetch sites with specific species in viewport (for map filtering)
    public func fetchWithSpeciesFilter(
        minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
        speciesIds: [String],
        likelihood: SiteSpeciesLink.Likelihood? = nil,
        limit: Int = 500
    ) throws -> [SiteLite] {
        guard !speciesIds.isEmpty else {
            return try fetchInBoundsLite(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon, limit: limit)
        }

        return try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let placeholders = speciesIds.map { _ in "?" }.joined(separator: ",")
            var sql = """
            SELECT DISTINCT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            INNER JOIN site_species ss ON s.id = ss.site_id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
              AND ss.species_id IN (\(placeholders))
            """

            var args: [DatabaseValueConvertible] = [minLat, maxLat, minLon, maxLon]
            args.append(contentsOf: speciesIds)

            if hideLegacy {
                sql += " AND \(legacyFilter)"
            }

            if let likelihood = likelihood {
                sql += " AND ss.likelihood = ?"
                args.append(likelihood.rawValue)
            }

            sql += " ORDER BY s.name LIMIT ?"
            args.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.map { row in
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

    /// Get sites with the most species diversity
    public func fetchBySpeciesDiversity(limit: Int = 20) throws -> [SiteLite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? "WHERE \(legacyFilter)" : ""
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist,
                   COUNT(ss.species_id) as species_count
            FROM sites s
            LEFT JOIN site_species ss ON s.id = ss.site_id
            \(legacyClause)
            GROUP BY s.id
            HAVING species_count > 0
            ORDER BY species_count DESC
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return rows.map { row in
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

    // MARK: - Proximity Queries

    /// Fetch sites near a location within a radius.
    /// Uses bounding box approximation for performance.
    public func fetchNearby(
        latitude: Double,
        longitude: Double,
        radiusKm: Double,
        limit: Int = 50
    ) throws -> [DiveSite] {
        // Approximate degree conversion (1 degree ≈ 111km at equator)
        let latDelta = radiusKm / 111.0
        let lonDelta = radiusKm / (111.0 * cos(latitude * .pi / 180))

        let minLat = latitude - latDelta
        let maxLat = latitude + latDelta
        let minLon = longitude - lonDelta
        let maxLon = longitude + lonDelta

        return try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyClause = hideLegacy ? " AND \(legacyFilterSQL())" : ""
            let sql = """
            SELECT *,
                   (
                       (latitude - ?) * (latitude - ?) +
                       (longitude - ?) * (longitude - ?) * COS(? * 0.0174533) * COS(? * 0.0174533)
                   ) as distance_sq
            FROM sites
            WHERE latitude BETWEEN ? AND ?
              AND longitude BETWEEN ? AND ?
              \(legacyClause)
            ORDER BY distance_sq
            LIMIT ?
            """

            return try DiveSite.fetchAll(
                db,
                sql: sql,
                arguments: [
                    latitude, latitude,
                    longitude, longitude,
                    latitude, latitude,
                    minLat, maxLat,
                    minLon, maxLon,
                    limit
                ]
            )
        }
    }

    // MARK: - v5: Geographic Hierarchy Queries

    /// Fetch sites by country
    public func fetchByCountry(_ countryId: String) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.countryId == countryId)
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

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

    /// Fetch sites by region (normalized)
    public func fetchByRegionId(_ regionId: String) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.regionId == regionId)
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

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

    /// Fetch sites by area
    public func fetchByArea(_ areaId: String) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.areaId == areaId)
                .order(DiveSite.Columns.name)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

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
}
