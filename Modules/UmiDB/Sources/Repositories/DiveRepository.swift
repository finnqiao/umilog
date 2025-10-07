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
