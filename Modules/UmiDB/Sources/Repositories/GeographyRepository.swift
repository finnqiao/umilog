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
                try country.insert(db)
            }
        }
    }

    public func createRegions(_ regions: [Region]) throws {
        try database.write { db in
            for region in regions {
                try region.insert(db)
            }
        }
    }

    public func createAreas(_ areas: [Area]) throws {
        try database.write { db in
            for area in areas {
                try area.insert(db)
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
}
