import Foundation
import GRDB

/// Repository for geographic hierarchy (Country -> Region -> Area)
public final class GeographyRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Countries

    /// Fetch all countries with dive sites
    public func fetchCountries() throws -> [Country] {
        try database.read { db in
            try Country.order(Column("name")).fetchAll(db)
        }
    }

    /// Fetch a country by ID
    public func fetchCountry(id: String) throws -> Country? {
        try database.read { db in
            try Country.fetchOne(db, key: id)
        }
    }

    /// Fetch countries by continent
    public func fetchCountries(continent: String) throws -> [Country] {
        try database.read { db in
            try Country
                .filter(Country.Columns.continent == continent)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    /// Search countries by name
    public func searchCountries(query: String, limit: Int = 5) throws -> [Country] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        return try database.read { db in
            let like = "%\(query)%"
            return try Country
                .filter(Country.Columns.name.like(like))
                .order(Column("name"))
                .limit(limit)
                .fetchAll(db)
        }
    }

    /// Get all unique continents
    public func fetchContinents() throws -> [String] {
        try database.read { db in
            try String.fetchAll(db, sql: "SELECT DISTINCT continent FROM countries ORDER BY continent")
        }
    }

    // MARK: - Regions

    /// Fetch all regions
    public func fetchRegions() throws -> [Region] {
        try database.read { db in
            try Region.order(Column("name")).fetchAll(db)
        }
    }

    /// Fetch a region by ID
    public func fetchRegion(id: String) throws -> Region? {
        try database.read { db in
            try Region.fetchOne(db, key: id)
        }
    }

    /// Fetch a region by ID or name (case-insensitive).
    public func fetchRegion(idOrName: String) throws -> Region? {
        try database.read { db in
            if let region = try Region.fetchOne(db, key: idOrName) {
                return region
            }
            return try Region
                .filter(Region.Columns.name.collating(.nocase) == idOrName)
                .fetchOne(db)
        }
    }

    /// Fetch regions for a country
    public func fetchRegions(countryId: String) throws -> [Region] {
        try database.read { db in
            try Region
                .filter(Region.Columns.countryId == countryId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    // MARK: - Areas

    /// Fetch all areas
    public func fetchAreas() throws -> [Area] {
        try database.read { db in
            try Area.order(Column("name")).fetchAll(db)
        }
    }

    /// Fetch an area by ID
    public func fetchArea(id: String) throws -> Area? {
        try database.read { db in
            try Area.fetchOne(db, key: id)
        }
    }

    /// Fetch areas for a region
    public func fetchAreas(regionId: String) throws -> [Area] {
        try database.read { db in
            try Area
                .filter(Area.Columns.regionId == regionId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    /// Fetch areas for a country
    public func fetchAreas(countryId: String) throws -> [Area] {
        try database.read { db in
            try Area
                .filter(Area.Columns.countryId == countryId)
                .order(Column("name"))
                .fetchAll(db)
        }
    }

    // MARK: - Hierarchy Queries

    /// Get the full geographic hierarchy for a site
    public func fetchHierarchy(siteId: String) throws -> (country: Country?, region: Region?, area: Area?) {
        try database.read { db in
            guard let site = try DiveSite.fetchOne(db, key: siteId) else {
                return (nil, nil, nil)
            }
            let country = try site.countryId.flatMap { try Country.fetchOne(db, key: $0) }
            let region = try site.regionId.flatMap { try Region.fetchOne(db, key: $0) }
            let area = try site.areaId.flatMap { try Area.fetchOne(db, key: $0) }
            return (country, region, area)
        }
    }

    /// Get site counts per region
    public func fetchRegionSiteCounts() throws -> [(region: String, count: Int)] {
        try database.read { db in
            let sql = """
            SELECT region, COUNT(*) as count
            FROM sites
            GROUP BY region
            ORDER BY count DESC
            """
            return try Row.fetchAll(db, sql: sql).map { row in
                (region: row["region"] as String, count: row["count"] as Int)
            }
        }
    }

    /// Get site counts per country
    public func fetchCountrySiteCounts() throws -> [(countryId: String, countryName: String, count: Int)] {
        try database.read { db in
            let sql = """
            SELECT c.id, c.name, COUNT(s.id) as count
            FROM countries c
            LEFT JOIN sites s ON s.country_id = c.id
            GROUP BY c.id
            ORDER BY count DESC
            """
            return try Row.fetchAll(db, sql: sql).map { row in
                (countryId: row["id"] as String,
                 countryName: row["name"] as String,
                 count: row["count"] as Int)
            }
        }
    }

    // MARK: - Create/Update

    public func createCountries(_ countries: [Country]) throws {
        try database.write { db in
            for country in countries {
                try country.save(db)
            }
        }
    }

    public func createRegions(_ regions: [Region]) throws {
        try database.write { db in
            for region in regions {
                try region.save(db)
            }
        }
    }

    public func createAreas(_ areas: [Area]) throws {
        try database.write { db in
            for area in areas {
                try area.save(db)
            }
        }
    }

    // MARK: - Counts

    public func countCountries() throws -> Int {
        try database.read { db in
            try Country.fetchCount(db)
        }
    }

    public func countRegions() throws -> Int {
        try database.read { db in
            try Region.fetchCount(db)
        }
    }

    public func countAreas() throws -> Int {
        try database.read { db in
            try Area.fetchCount(db)
        }
    }

    // MARK: - Geographic Bounds

    /// Geographic bounding box
    public struct Bounds {
        public let minLat: Double
        public let maxLat: Double
        public let minLon: Double
        public let maxLon: Double

        public var centerLat: Double { (minLat + maxLat) / 2 }
        public var centerLon: Double { (minLon + maxLon) / 2 }
        public var latSpan: Double { maxLat - minLat }
        public var lonSpan: Double { maxLon - minLon }
    }

    /// Fetch bounds of all sites in a country
    public func fetchBounds(countryId: String) throws -> Bounds? {
        try database.read { db in
            let sql = """
            SELECT MIN(latitude) as minLat, MAX(latitude) as maxLat,
                   MIN(longitude) as minLon, MAX(longitude) as maxLon
            FROM sites WHERE country_id = ?
            """
            guard let row = try Row.fetchOne(db, sql: sql, arguments: [countryId]),
                  let minLat: Double = row["minLat"],
                  let maxLat: Double = row["maxLat"],
                  let minLon: Double = row["minLon"],
                  let maxLon: Double = row["maxLon"] else {
                return nil
            }
            return Bounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        }
    }

    /// Fetch bounds of all sites in a region
    public func fetchBounds(regionId: String) throws -> Bounds? {
        try database.read { db in
            let sql = """
            SELECT MIN(latitude) as minLat, MAX(latitude) as maxLat,
                   MIN(longitude) as minLon, MAX(longitude) as maxLon
            FROM sites WHERE region_id = ? OR region = ?
            """
            guard let row = try Row.fetchOne(db, sql: sql, arguments: [regionId, regionId]),
                  let minLat: Double = row["minLat"],
                  let maxLat: Double = row["maxLat"],
                  let minLon: Double = row["minLon"],
                  let maxLon: Double = row["maxLon"] else {
                return nil
            }
            return Bounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        }
    }

    /// Fetch bounds for a list of site IDs
    public func fetchBounds(siteIds: [String]) throws -> Bounds? {
        guard !siteIds.isEmpty else { return nil }
        return try database.read { db in
            let placeholders = siteIds.map { _ in "?" }.joined(separator: ",")
            let sql = """
            SELECT MIN(latitude) as minLat, MAX(latitude) as maxLat,
                   MIN(longitude) as minLon, MAX(longitude) as maxLon
            FROM sites WHERE id IN (\(placeholders))
            """
            guard let row = try Row.fetchOne(db, sql: sql, arguments: StatementArguments(siteIds)),
                  let minLat: Double = row["minLat"],
                  let maxLat: Double = row["maxLat"],
                  let minLon: Double = row["minLon"],
                  let maxLon: Double = row["maxLon"] else {
                return nil
            }
            return Bounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
        }
    }

    // MARK: - Region Summaries

    // MARK: - Viewport Aggregate Queries

    /// Fetch regions visible in a bounding box, with site counts and center coordinates.
    /// Used at world zoom to show destination markers.
    public func fetchRegionsInBounds(
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double,
        limit: Int = 30
    ) throws -> [RegionSummary] {
        try database.read { db in
            let sql = """
            SELECT r.id, r.name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   COALESCE(r.latitude, AVG(s.latitude)) as center_lat,
                   COALESCE(r.longitude, AVG(s.longitude)) as center_lon
            FROM regions r
            LEFT JOIN countries c ON r.country_id = c.id
            INNER JOIN sites s ON s.region_id = r.id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
            GROUP BY r.id
            HAVING site_count > 0
            ORDER BY site_count DESC
            LIMIT ?
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [minLat, maxLat, minLon, maxLon, limit])
            return rows.compactMap { row -> RegionSummary? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else { return nil }
                return RegionSummary(
                    id: id,
                    name: name,
                    countryName: row["country_name"] ?? "Unknown",
                    siteCount: row["site_count"] ?? 0,
                    centerLat: centerLat,
                    centerLon: centerLon,
                    zoomLevel: 7.0
                )
            }
        }
    }

    /// Fetch areas visible in a bounding box, with site counts and center coordinates.
    /// Used at regional zoom to show named area markers.
    public func fetchAreasInBounds(
        minLat: Double, maxLat: Double,
        minLon: Double, maxLon: Double,
        limit: Int = 50
    ) throws -> [AreaSummary] {
        try database.read { db in
            let sql = """
            SELECT a.id, a.name, a.region_id, r.name as region_name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   COALESCE(a.latitude, AVG(s.latitude)) as center_lat,
                   COALESCE(a.longitude, AVG(s.longitude)) as center_lon
            FROM areas a
            LEFT JOIN regions r ON a.region_id = r.id
            LEFT JOIN countries c ON a.country_id = c.id
            INNER JOIN sites s ON s.area_id = a.id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
            GROUP BY a.id
            HAVING site_count > 0
            ORDER BY site_count DESC
            LIMIT ?
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [minLat, maxLat, minLon, maxLon, limit])
            return rows.compactMap { row -> AreaSummary? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else { return nil }
                return AreaSummary(
                    id: id,
                    name: name,
                    regionId: row["region_id"],
                    regionName: row["region_name"],
                    countryName: row["country_name"],
                    siteCount: row["site_count"] ?? 0,
                    centerLat: centerLat,
                    centerLon: centerLon
                )
            }
        }
    }

    /// Fetch areas within a specific region, with site counts.
    public func fetchAreasWithCounts(regionId: String) throws -> [AreaSummary] {
        try database.read { db in
            let sql = """
            SELECT a.id, a.name, a.region_id, r.name as region_name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   COALESCE(a.latitude, AVG(s.latitude)) as center_lat,
                   COALESCE(a.longitude, AVG(s.longitude)) as center_lon
            FROM areas a
            LEFT JOIN regions r ON a.region_id = r.id
            LEFT JOIN countries c ON a.country_id = c.id
            LEFT JOIN sites s ON s.area_id = a.id
            WHERE a.region_id = ?
            GROUP BY a.id
            HAVING site_count > 0
            ORDER BY site_count DESC
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [regionId])
            return rows.compactMap { row -> AreaSummary? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else { return nil }
                return AreaSummary(
                    id: id,
                    name: name,
                    regionId: row["region_id"],
                    regionName: row["region_name"],
                    countryName: row["country_name"],
                    siteCount: row["site_count"] ?? 0,
                    centerLat: centerLat,
                    centerLon: centerLon
                )
            }
        }
    }

    /// Fetch nearby areas sorted by distance from a coordinate.
    public func fetchNearbyAreas(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 500,
        limit: Int = 10
    ) throws -> [AreaSummary] {
        try database.read { db in
            let latDelta = radiusKm / 111.0
            let lonDelta = radiusKm / (111.0 * cos(latitude * .pi / 180))
            let sql = """
            SELECT a.id, a.name, a.region_id, r.name as region_name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   COALESCE(a.latitude, AVG(s.latitude)) as center_lat,
                   COALESCE(a.longitude, AVG(s.longitude)) as center_lon
            FROM areas a
            LEFT JOIN regions r ON a.region_id = r.id
            LEFT JOIN countries c ON a.country_id = c.id
            INNER JOIN sites s ON s.area_id = a.id
            WHERE s.latitude BETWEEN ? AND ?
              AND s.longitude BETWEEN ? AND ?
            GROUP BY a.id
            HAVING site_count > 0
            ORDER BY (center_lat - ?) * (center_lat - ?) + (center_lon - ?) * (center_lon - ?) * ? ASC
            LIMIT ?
            """
            let cosLat = cos(latitude * .pi / 180)
            let rows = try Row.fetchAll(db, sql: sql, arguments: [
                latitude - latDelta, latitude + latDelta,
                longitude - lonDelta, longitude + lonDelta,
                latitude, latitude, longitude, longitude, cosLat * cosLat,
                limit
            ])
            return rows.compactMap { row -> AreaSummary? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else { return nil }
                return AreaSummary(
                    id: id,
                    name: name,
                    regionId: row["region_id"],
                    regionName: row["region_name"],
                    countryName: row["country_name"],
                    siteCount: row["site_count"] ?? 0,
                    centerLat: centerLat,
                    centerLon: centerLon
                )
            }
        }
    }

    /// Fetch popular regions with site counts, ordered by site density.
    public func fetchPopularRegions(limit: Int = 10) throws -> [RegionSummary] {
        try database.read { db in
            let sql = """
            SELECT r.id, r.name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   AVG(s.latitude) as center_lat,
                   AVG(s.longitude) as center_lon
            FROM regions r
            LEFT JOIN countries c ON r.country_id = c.id
            LEFT JOIN sites s ON s.region_id = r.id
            GROUP BY r.id
            HAVING site_count > 0
            ORDER BY site_count DESC
            LIMIT ?
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: [limit])
            return rows.compactMap { row -> RegionSummary? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else {
                    return nil
                }

                return RegionSummary(
                    id: id,
                    name: name,
                    countryName: row["country_name"] ?? "Unknown",
                    siteCount: row["site_count"] ?? 0,
                    imageURL: nil,
                    centerLat: centerLat,
                    centerLon: centerLon,
                    zoomLevel: 7.0
                )
            }
        }
    }

    /// Fetch region summaries by IDs (for recently viewed regions).
    public func fetchRegionSummaries(ids: [String]) throws -> [RegionSummary] {
        guard !ids.isEmpty else { return [] }

        return try database.read { db in
            let placeholders = ids.map { _ in "?" }.joined(separator: ",")
            let sql = """
            SELECT r.id, r.name, c.name as country_name,
                   COUNT(s.id) as site_count,
                   AVG(s.latitude) as center_lat,
                   AVG(s.longitude) as center_lon
            FROM regions r
            LEFT JOIN countries c ON r.country_id = c.id
            LEFT JOIN sites s ON s.region_id = r.id
            WHERE r.id IN (\(placeholders))
            GROUP BY r.id
            """

            let rows = try Row.fetchAll(db, sql: sql, arguments: StatementArguments(ids))
            let summaryMap = Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (String, RegionSummary)? in
                guard let id: String = row["id"],
                      let name: String = row["name"],
                      let centerLat: Double = row["center_lat"],
                      let centerLon: Double = row["center_lon"] else {
                    return nil
                }

                let summary = RegionSummary(
                    id: id,
                    name: name,
                    countryName: row["country_name"] ?? "Unknown",
                    siteCount: row["site_count"] ?? 0,
                    imageURL: nil,
                    centerLat: centerLat,
                    centerLon: centerLon,
                    zoomLevel: 7.0
                )
                return (id, summary)
            })

            // Preserve order of input IDs
            return ids.compactMap { summaryMap[$0] }
        }
    }

    /// Fetch a single region summary by ID.
    public func fetchRegionSummary(id: String) throws -> RegionSummary? {
        let results = try fetchRegionSummaries(ids: [id])
        return results.first
    }
}
