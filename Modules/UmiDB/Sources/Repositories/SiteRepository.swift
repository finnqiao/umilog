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

    private func rankedOrderSQL(alias: String? = nil) -> String {
        let prefix = alias.map { "\($0)." } ?? ""
        return """
        COALESCE(\(prefix)curation_score, 0) DESC,
        COALESCE(\(prefix)popularity_score, 0) DESC,
        COALESCE(\(prefix)visitedCount, 0) DESC,
        \(prefix)name COLLATE NOCASE ASC
        """
    }

    private func normalizedSearchValue(_ value: String) -> String {
        let lowered = value.lowercased()
        let flattened = lowered.map { character -> Character in
            character.isLetter || character.isNumber ? character : " "
        }
        return String(flattened)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .joined(separator: " ")
    }

    private func makeSiteLite(from row: Row) -> SiteLite {
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

    private func makeSiteLite(from site: DiveSite) -> SiteLite {
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

    private func syncAliases(for site: DiveSite, in db: Database) throws {
        try db.execute(sql: "DELETE FROM site_aliases WHERE site_id = ?", arguments: [site.id])

        var seen = Set<String>()
        seen.insert(normalizedSearchValue(site.name))

        for alias in site.aliases {
            let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalizedSearchValue(trimmed)
            guard !trimmed.isEmpty, !normalized.isEmpty, !seen.contains(normalized) else {
                continue
            }
            seen.insert(normalized)
            try db.execute(
                sql: "INSERT INTO site_aliases (site_id, alias, alias_normalized) VALUES (?, ?, ?)",
                arguments: [site.id, trimmed, normalized]
            )
        }
    }

    private func rebuildSite(
        from site: DiveSite,
        wishlist: Bool? = nil,
        isPlanned: Bool? = nil,
        visitedCount: Int? = nil
    ) -> DiveSite {
        DiveSite(
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
            wishlist: wishlist ?? site.wishlist,
            isPlanned: isPlanned ?? site.isPlanned,
            visitedCount: visitedCount ?? site.visitedCount,
            tags: site.tags,
            createdAt: site.createdAt,
            countryId: site.countryId,
            regionId: site.regionId,
            areaId: site.areaId,
            wikidataId: site.wikidataId,
            osmId: site.osmId,
            aliases: site.aliases,
            curationScore: site.curationScore,
            popularityScore: site.popularityScore,
            accessLevel: site.accessLevel,
            wreckVerified: site.wreckVerified,
            destinationSlug: site.destinationSlug
        )
    }
    
    // MARK: - Create
    
    public func create(_ site: DiveSite) throws {
        try database.write { db in
            try site.insert(db)
            try syncAliases(for: site, in: db)
        }
    }
    
    public func createMany(_ sites: [DiveSite]) throws {
        try database.write { db in
            for site in sites {
                try site.insert(db)
                try syncAliases(for: site, in: db)
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
            let sql = """
            SELECT s.*
            FROM sites s
            \(legacyClause)
            ORDER BY \(rankedOrderSQL(alias: "s"))
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
            let hideLegacy = try shouldHideLegacySites(db)
            let sql = hideLegacy ? "SELECT COUNT(*) FROM sites WHERE \(legacyFilterSQL())" : "SELECT COUNT(*) FROM sites"
            return try Int.fetchOne(db, sql: sql) ?? 0
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
            let sql = """
            SELECT s.*
            FROM sites s
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
              \(legacyClause)
            ORDER BY \(rankedOrderSQL(alias: "s"))
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
    /// Sorted by curation quality, popularity, and visits.
    public func fetchInBoundsLite(minLat: Double, maxLat: Double, minLon: Double, maxLon: Double,
                                   filters: SiteFilters = SiteFilters(), limit: Int = 500) throws -> [SiteLite] {
        try database.read { db in
            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist
            FROM sites s
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
              \(legacyClause)
            ORDER BY \(rankedOrderSQL(alias: "s"))
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [minLat, maxLat, minLon, maxLon, limit])
            return rows.map(makeSiteLite(from:))
        }
    }
    
    public func search(query: String) throws -> [DiveSite] {
        try database.read { db in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            let hideLegacy = try shouldHideLegacySites(db)
            let legacyClause = hideLegacy ? " AND \(legacyFilterSQL(alias: "s"))" : ""
            let normalized = normalizedSearchValue(trimmed)
            let like = "%\(trimmed)%"
            let normalizedLike = "%\(normalized)%"
            let prefixLike = "\(normalized)%"
            let sql = """
            SELECT s.*
            FROM sites s
            LEFT JOIN site_aliases sa ON sa.site_id = s.id
            WHERE (
                LOWER(s.name) LIKE LOWER(?)
                OR LOWER(s.location) LIKE LOWER(?)
                OR LOWER(COALESCE(s.destination_slug, '')) LIKE LOWER(?)
                OR sa.alias_normalized LIKE ?
            )\(legacyClause)
            GROUP BY s.id
            ORDER BY
                MAX(
                    CASE
                        WHEN LOWER(s.name) = LOWER(?) THEN 900
                        WHEN sa.alias_normalized = ? THEN 850
                        WHEN LOWER(s.name) LIKE LOWER(?) THEN 700
                        WHEN sa.alias_normalized LIKE ? THEN 650
                        WHEN LOWER(COALESCE(s.destination_slug, '')) LIKE LOWER(?) THEN 500
                        ELSE 0
                    END
                ) DESC,
                \(rankedOrderSQL(alias: "s"))
            """
            return try DiveSite.fetchAll(
                db,
                sql: sql,
                arguments: [
                    like, like, like, normalizedLike,
                    trimmed, normalized, like, prefixLike, like
                ]
            )
        }
    }
    
    /// v3: FTS5 search with weighted ranking and BM25 scoring
    /// Weighted scoring favors names and aliases, then curation/popularity.
    public func searchFTS(query: String, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let normalized = normalizedSearchValue(trimmed)
            let prefixQuery = normalized
                .split(separator: " ")
                .map { "\($0)*" }
                .joined(separator: " ")
            let ftsQuery = prefixQuery.isEmpty ? normalized : "\(normalized) OR \(prefixQuery)"
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type, 
                   s.tags, s.region, s.visitedCount, s.wishlist,
                   (
                       -bm25(sites_fts, 8.0, 6.0, 2.5, 2.0, 1.5, 0.75)
                       + COALESCE(s.curation_score, 0) * 25.0
                       + COALESCE(s.popularity_score, 0) * 10.0
                       + COALESCE(s.visitedCount, 0)
                       + MAX(
                            CASE
                                WHEN LOWER(s.name) = LOWER(?) THEN 200
                                WHEN sa.alias_normalized = ? THEN 180
                                WHEN LOWER(COALESCE(s.destination_slug, '')) = LOWER(?) THEN 160
                                ELSE 0
                            END
                         )
                   ) as weighted_rank
            FROM sites_fts
            INNER JOIN sites s ON s.rowid = sites_fts.rowid
            LEFT JOIN site_aliases sa ON sa.site_id = s.id
            WHERE sites_fts MATCH ?\(legacyClause)
            GROUP BY s.id
            ORDER BY weighted_rank DESC, \(rankedOrderSQL(alias: "s"))
            LIMIT ?
            """
            
            let sites = try Row.fetchAll(db, sql: sql, 
                                        arguments: [trimmed, normalized, trimmed, ftsQuery, limit])
            
            return sites.map(makeSiteLite(from:))
        }
    }
    
    /// Prefix matching for autocomplete-style search
    /// Supports partial word matching using FTS5 prefix syntax (e.g., "wreck*")
    public func searchPrefix(prefix: String, limit: Int = 20) throws -> [SiteLite] {
        try database.read { db in
            let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return [] }

            let hideLegacy = try shouldHideLegacySites(db)
            let legacyFilter = legacyFilterSQL(alias: "s")
            let legacyClause = hideLegacy ? " AND \(legacyFilter)" : ""
            let sanitizedPrefix = normalizedSearchValue(trimmed)
                .split(separator: " ")
                .map { "\($0)*" }
                .joined(separator: " ")
            
            let sql = """
            SELECT s.id, s.name, s.latitude, s.longitude, s.difficulty, s.type,
                   s.tags, s.region, s.visitedCount, s.wishlist,
                   (
                       -bm25(sites_fts, 8.0, 6.0, 2.5, 2.0, 1.5, 0.75)
                       + COALESCE(s.curation_score, 0) * 25.0
                       + COALESCE(s.popularity_score, 0) * 10.0
                       + COALESCE(s.visitedCount, 0)
                   ) as weighted_rank
            FROM sites_fts
            INNER JOIN sites s ON s.rowid = sites_fts.rowid
            WHERE sites_fts MATCH ?\(legacyClause)
            ORDER BY weighted_rank DESC, \(rankedOrderSQL(alias: "s"))
            LIMIT ?
            """
            
            let sites = try Row.fetchAll(db, sql: sql, 
                                        arguments: [sanitizedPrefix, limit])
            
            return sites.map(makeSiteLite(from:))
        }
    }
    
    /// v3: Fetch by tag
    public func fetchByTag(_ tag: String) throws -> [SiteLite] {
        try database.read { db in
            let like = "%\"\(tag)\"%"
            var request = DiveSite
                .filter(DiveSite.Columns.tags.like(like))
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)
            
            return sites.map(makeSiteLite(from:))
        }
    }

    /// Fetch sites by type (lightweight payload).
    public func fetchByType(_ type: DiveSite.SiteType, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.type == type.rawValue)
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
                .limit(limit)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

            return sites.map(makeSiteLite(from:))
        }
    }

    /// Fetch sites by difficulty (lightweight payload).
    public func fetchByDifficulty(_ difficulty: DiveSite.Difficulty, limit: Int = 50) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.difficulty == difficulty.rawValue)
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
                .limit(limit)
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

            return sites.map(makeSiteLite(from:))
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
            try syncAliases(for: updatedSite, in: db)
        }
    }
    
    public func toggleWishlist(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
            let updated = rebuildSite(from: site, wishlist: !site.wishlist)
            try updated.update(db)
            try syncAliases(for: updated, in: db)
        }
    }

    /// v6: Toggle planned status for a site
    public func togglePlanned(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
            let updated = rebuildSite(from: site, isPlanned: !site.isPlanned)
            try updated.update(db)
            try syncAliases(for: updated, in: db)
        }
    }

    /// v6: Set planned status for a site (without toggling)
    public func setPlanned(siteId: String, isPlanned: Bool) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
            guard site.isPlanned != isPlanned else { return }  // No change needed
            let updated = rebuildSite(from: site, isPlanned: isPlanned)
            try updated.update(db)
            try syncAliases(for: updated, in: db)
        }
    }

    // MARK: - Visited Count

    public func incrementVisitedCount(siteId: String) throws {
        try database.write { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else { return }
            let updated = rebuildSite(from: site, visitedCount: site.visitedCount + 1)
            try updated.update(db)
            try syncAliases(for: updated, in: db)
        }
    }

    // MARK: - Delete

    public func delete(id: String) throws {
        _ = try database.write { db in
            try db.execute(sql: "DELETE FROM site_aliases WHERE site_id = ?", arguments: [id])
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
                \(rankedOrderSQL(alias: "s"))
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [speciesId])
            return rows.map(makeSiteLite(from:))
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

            sql += " ORDER BY \(rankedOrderSQL(alias: "s")) LIMIT ?"
            args.append(limit)

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(args))
            return rows.map(makeSiteLite(from:))
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
            ORDER BY species_count DESC, \(rankedOrderSQL(alias: "s"))
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return rows.map(makeSiteLite(from:))
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
            ORDER BY distance_sq ASC, \(rankedOrderSQL())
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
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

            return sites.map(makeSiteLite(from:))
        }
    }

    /// Fetch sites by region (normalized)
    public func fetchByRegionId(_ regionId: String) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.regionId == regionId)
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

            return sites.map(makeSiteLite(from:))
        }
    }

    /// Fetch sites by area
    public func fetchByArea(_ areaId: String) throws -> [SiteLite] {
        try database.read { db in
            var request = DiveSite
                .filter(DiveSite.Columns.areaId == areaId)
                .order(
                    DiveSite.Columns.curationScore.desc,
                    DiveSite.Columns.popularityScore.desc,
                    DiveSite.Columns.visitedCount.desc,
                    DiveSite.Columns.name
                )
            if try shouldHideLegacySites(db) {
                request = request.filter(sql: legacyFilterSQL())
            }
            let sites = try request.fetchAll(db)

            return sites.map(makeSiteLite(from:))
        }
    }
}
