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
        var updatedDive = dive
        // Update timestamp (need to make struct mutable first)
        try database.write { db in
            try updatedDive.update(db)
        }
    }
    
    // MARK: - Delete
    
    public func delete(id: String) throws {
        try database.write { db in
            try DiveLog.deleteOne(db, key: id)
        }
    }
    
    // MARK: - Async Methods
    
    public func getAllDives() async throws -> [DiveLog] {
        try await database.read { db in
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
