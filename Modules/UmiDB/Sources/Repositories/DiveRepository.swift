import Foundation
import GRDB

public final class DiveRepository {
    private let database: AppDatabase
    
    public init(database: AppDatabase) {
        self.database = database
    }
    
    // MARK: - Create
    
    public func create(_ dive: DiveLog) throws {
        try database.write { db in
            try dive.insert(db)
        }
    }
    
    // MARK: - Read
    
    public func fetch(id: String) throws -> DiveLog? {
        try database.read { db in
            try DiveLog.fetchOne(db, key: id)
        }
    }
    
    public func fetchAll() throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }
    
    public func fetchRecent(limit: Int = 10) throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .order(DiveLog.Columns.startTime.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }
    
    public func fetchBySite(siteId: String) throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .filter(DiveLog.Columns.siteId == siteId)
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }
    
    // MARK: - Update
    
    public func update(_ dive: DiveLog) throws {
        let updatedDive = dive
        // Update timestamp (need to make struct mutable first)
        try database.write { db in
            try updatedDive.update(db)
        }
    }
    
    // MARK: - Delete
    
    public func delete(id: String) throws {
        _ = try database.write { db in
            try DiveLog.deleteOne(db, key: id)
        }
    }
    
    // MARK: - Async Methods
    
    public func getAllDives() async throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }
    
    // MARK: - Sync Methods for Map
    
    public func getAllDivesSync() throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }
    
    public func getDivesForSiteSync(siteId: String) throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .filter(DiveLog.Columns.siteId == siteId)
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }
    
    // MARK: - GPS Draft Methods (v6)

    /// Fetch dives with pending GPS coordinates (no site assigned)
    public func fetchPendingGPS() throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .filter(DiveLog.Columns.siteId == nil)
                .filter(DiveLog.Columns.pendingLatitude != nil)
                .filter(DiveLog.Columns.pendingLongitude != nil)
                .order(DiveLog.Columns.startTime.desc)
                .fetchAll(db)
        }
    }

    /// Link a pending GPS dive to a site and clear GPS coordinates
    public func linkToSite(diveId: String, siteId: String) throws {
        try database.write { db in
            guard let dive = try DiveLog.fetchOne(db, key: diveId) else { return }

            let updated = DiveLog(
                id: dive.id,
                siteId: siteId,
                pendingLatitude: nil,
                pendingLongitude: nil,
                date: dive.date,
                startTime: dive.startTime,
                endTime: dive.endTime,
                maxDepth: dive.maxDepth,
                averageDepth: dive.averageDepth,
                bottomTime: dive.bottomTime,
                startPressure: dive.startPressure,
                endPressure: dive.endPressure,
                temperature: dive.temperature,
                visibility: dive.visibility,
                current: dive.current,
                conditions: dive.conditions,
                notes: dive.notes,
                instructorName: dive.instructorName,
                instructorNumber: dive.instructorNumber,
                signed: dive.signed,
                gasMixesJson: dive.gasMixesJson,
                computerDiveNumber: dive.computerDiveNumber,
                surfaceInterval: dive.surfaceInterval,
                safetyStopPerformed: dive.safetyStopPerformed,
                createdAt: dive.createdAt,
                updatedAt: Date()
            )
            try updated.update(db)
        }
    }

    // MARK: - Duplicate Detection

    /// Check if a dive with the same date and max depth already exists
    public func hasDuplicate(date: Date, maxDepth: Double) throws -> Bool {
        try database.read { db in
            // Match by date (within 1 hour) and depth (within 0.5m)
            let dateStart = date.addingTimeInterval(-3600)
            let dateEnd = date.addingTimeInterval(3600)
            let depthMin = maxDepth - 0.5
            let depthMax = maxDepth + 0.5

            let count = try DiveLog
                .filter(DiveLog.Columns.date >= dateStart)
                .filter(DiveLog.Columns.date <= dateEnd)
                .filter(DiveLog.Columns.maxDepth >= depthMin)
                .filter(DiveLog.Columns.maxDepth <= depthMax)
                .fetchCount(db)

            return count > 0
        }
    }

    // MARK: - Statistics

    /// Returns a dictionary of siteId → dive count for all sites with logged dives.
    /// Used for Resy-style "X dives" badges on site cards.
    public func diveCountsBySite() async throws -> [String: Int] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT siteId, COUNT(*) as count
                FROM dives
                WHERE siteId IS NOT NULL
                GROUP BY siteId
                """)
            var result: [String: Int] = [:]
            for row in rows {
                if let siteId = row["siteId"] as? String,
                   let count = row["count"] as? Int {
                    result[siteId] = count
                }
            }
            return result
        }
    }

    /// Sync version of dive counts for immediate access.
    public func diveCountsBySiteSync() throws -> [String: Int] {
        try database.read { db in
            let rows = try Row.fetchAll(db, sql: """
                SELECT siteId, COUNT(*) as count
                FROM dives
                WHERE siteId IS NOT NULL
                GROUP BY siteId
                """)
            var result: [String: Int] = [:]
            for row in rows {
                if let siteId = row["siteId"] as? String,
                   let count = row["count"] as? Int {
                    result[siteId] = count
                }
            }
            return result
        }
    }

    /// Returns the most recent dive (for surface interval calculation).
    public func lastDive() async throws -> DiveLog? {
        try database.read { db in
            try DiveLog
                .order(DiveLog.Columns.endTime.desc)
                .limit(1)
                .fetchOne(db)
        }
    }

    public func calculateStats() throws -> DiveStats {
        try database.read { db in
            let count = try DiveLog.fetchCount(db)
            
            guard count > 0 else {
                return DiveStats.zero
            }
            
            let dives = try DiveLog.fetchAll(db)
            
            let maxDepth = dives.map(\.maxDepth).max() ?? 0
            let totalBottomTime = dives.reduce(0) { $0 + $1.bottomTime }
            let visitedSites = Set(dives.map(\.siteId)).count
            
            return DiveStats(
                totalDives: count,
                totalBottomTime: totalBottomTime,
                maxDepth: maxDepth,
                sitesVisited: visitedSites,
                speciesSpotted: 0 // TODO: Calculate from sightings
            )
        }
    }

    // MARK: - Heatmap Queries

    public func fetchHeatmapPoints() throws -> [DiveHeatmapPoint] {
        try database.read { db in
            var points: [DiveHeatmapPoint] = []

            let siteRows = try Row.fetchAll(
                db,
                sql: """
                SELECT s.latitude AS latitude,
                       s.longitude AS longitude,
                       s.name AS siteName,
                       COUNT(*) AS diveCount,
                       MAX(d.date) AS lastDiveDate
                FROM dives d
                INNER JOIN sites s ON s.id = d.siteId
                GROUP BY s.id
                """
            )

            for row in siteRows {
                guard let latitude = row["latitude"] as Double?,
                      let longitude = row["longitude"] as Double?,
                      let diveCount = row["diveCount"] as Int?,
                      let lastDiveDate = row["lastDiveDate"] as Date? else {
                    continue
                }
                points.append(
                    DiveHeatmapPoint(
                        latitude: latitude,
                        longitude: longitude,
                        diveCount: max(1, diveCount),
                        lastDiveDate: lastDiveDate,
                        siteName: row["siteName"]
                    )
                )
            }

            let gpsRows = try Row.fetchAll(
                db,
                sql: """
                SELECT pendingLatitude AS latitude,
                       pendingLongitude AS longitude,
                       COUNT(*) AS diveCount,
                       MAX(date) AS lastDiveDate
                FROM dives
                WHERE siteId IS NULL
                  AND pendingLatitude IS NOT NULL
                  AND pendingLongitude IS NOT NULL
                GROUP BY pendingLatitude, pendingLongitude
                """
            )

            for row in gpsRows {
                guard let latitude = row["latitude"] as Double?,
                      let longitude = row["longitude"] as Double?,
                      let diveCount = row["diveCount"] as Int?,
                      let lastDiveDate = row["lastDiveDate"] as Date? else {
                    continue
                }
                points.append(
                    DiveHeatmapPoint(
                        latitude: latitude,
                        longitude: longitude,
                        diveCount: max(1, diveCount),
                        lastDiveDate: lastDiveDate,
                        siteName: nil
                    )
                )
            }

            return points
        }
    }

    public func fetchHeatmapSummary() throws -> DiveHeatmapSummary {
        let points = try fetchHeatmapPoints()
        let totalDives = points.reduce(0) { $0 + $1.diveCount }
        let uniqueSites = points.count

        return try database.read { db in
            let countries = try Int.fetchOne(
                db,
                sql: """
                SELECT COUNT(DISTINCT s.country_id)
                FROM dives d
                INNER JOIN sites s ON s.id = d.siteId
                WHERE s.country_id IS NOT NULL
                """
            ) ?? 0

            let mostDivedRow = try Row.fetchOne(
                db,
                sql: """
                SELECT s.name AS siteName, COUNT(*) AS diveCount
                FROM dives d
                INNER JOIN sites s ON s.id = d.siteId
                GROUP BY s.id
                ORDER BY diveCount DESC
                LIMIT 1
                """
            )

            let mostDived: DiveHeatmapSummary.MostDivedSite? = {
                guard let row = mostDivedRow,
                      let siteName = row["siteName"] as String?,
                      let diveCount = row["diveCount"] as Int? else {
                    return nil
                }
                return .init(siteName: siteName, count: diveCount)
            }()

            return DiveHeatmapSummary(
                totalDives: totalDives,
                uniqueSites: uniqueSites,
                countries: countries,
                mostDivedSite: mostDived
            )
        }
    }
}

// MARK: - Stats Model
public struct DiveStats {
    public let totalDives: Int
    public let totalBottomTime: Int
    public let maxDepth: Double
    public let sitesVisited: Int
    public let speciesSpotted: Int
    
    public static let zero = DiveStats(
        totalDives: 0,
        totalBottomTime: 0,
        maxDepth: 0,
        sitesVisited: 0,
        speciesSpotted: 0
    )
}

public struct DiveHeatmapPoint: Equatable, Hashable {
    public let latitude: Double
    public let longitude: Double
    public let diveCount: Int
    public let lastDiveDate: Date
    public let siteName: String?

    public init(
        latitude: Double,
        longitude: Double,
        diveCount: Int,
        lastDiveDate: Date,
        siteName: String?
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.diveCount = diveCount
        self.lastDiveDate = lastDiveDate
        self.siteName = siteName
    }
}

public struct DiveHeatmapSummary {
    public struct MostDivedSite {
        public let siteName: String
        public let count: Int

        public init(siteName: String, count: Int) {
            self.siteName = siteName
            self.count = count
        }
    }

    public let totalDives: Int
    public let uniqueSites: Int
    public let countries: Int
    public let mostDivedSite: MostDivedSite?

    public init(
        totalDives: Int,
        uniqueSites: Int,
        countries: Int,
        mostDivedSite: MostDivedSite?
    ) {
        self.totalDives = totalDives
        self.uniqueSites = uniqueSites
        self.countries = countries
        self.mostDivedSite = mostDivedSite
    }
}
