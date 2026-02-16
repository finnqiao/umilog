import Foundation
import GRDB

public final class TripRepository {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    // MARK: - Create

    /// Create a new trip with the given sites
    public func create(_ trip: Trip, siteIds: [String]) throws {
        try database.write { db in
            try trip.insert(db)

            // Add sites with sort order
            for (index, siteId) in siteIds.enumerated() {
                let tripSite = TripSite(
                    tripId: trip.id,
                    siteId: siteId,
                    sortOrder: index
                )
                try tripSite.insert(db)
            }
        }
    }

    /// Create a trip quickly from a list of site IDs
    public func createFromSites(name: String, siteIds: [String]) throws -> Trip {
        let trip = Trip(name: name)
        try create(trip, siteIds: siteIds)
        return trip
    }

    // MARK: - Read

    public func fetch(id: String) throws -> Trip? {
        try database.read { db in
            try Trip.fetchOne(db, key: id)
        }
    }

    public func fetchAll() throws -> [Trip] {
        try database.read { db in
            try Trip
                .order(Trip.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    /// Fetch trips with upcoming dates first
    public func fetchUpcoming() throws -> [Trip] {
        let now = Date()
        return try database.read { db in
            try Trip
                .filter(Trip.Columns.startDate != nil)
                .filter(Trip.Columns.startDate >= now)
                .order(Trip.Columns.startDate.asc)
                .fetchAll(db)
        }
    }

    /// Fetch past trips (completed)
    public func fetchPast() throws -> [Trip] {
        let now = Date()
        return try database.read { db in
            try Trip
                .filter(Trip.Columns.endDate != nil)
                .filter(Trip.Columns.endDate < now)
                .order(Trip.Columns.endDate.desc)
                .fetchAll(db)
        }
    }

    /// Fetch sites for a trip
    public func fetchSites(tripId: String) throws -> [DiveSite] {
        try database.read { db in
            try DiveSite.fetchAll(db, sql: """
                SELECT s.* FROM dive_sites s
                INNER JOIN trip_sites ts ON ts.site_id = s.id
                WHERE ts.trip_id = ?
                ORDER BY ts.sort_order ASC
                """, arguments: [tripId])
        }
    }

    /// Fetch trip with its sites
    public func fetchWithSites(tripId: String) throws -> (Trip, [DiveSite])? {
        guard let trip = try fetch(id: tripId) else { return nil }
        let sites = try fetchSites(tripId: tripId)
        return (trip, sites)
    }

    // MARK: - Update

    public func update(_ trip: Trip) throws {
        try database.write { db in
            try trip.update(db)
        }
    }

    /// Update sites for a trip
    public func updateSites(tripId: String, siteIds: [String]) throws {
        try database.write { db in
            // Remove existing sites
            try TripSite
                .filter(TripSite.Columns.tripId == tripId)
                .deleteAll(db)

            // Add new sites
            for (index, siteId) in siteIds.enumerated() {
                let tripSite = TripSite(
                    tripId: tripId,
                    siteId: siteId,
                    sortOrder: index
                )
                try tripSite.insert(db)
            }

            // Update trip timestamp
            try db.execute(
                sql: "UPDATE trips SET updated_at = ? WHERE id = ?",
                arguments: [Date(), tripId]
            )
        }
    }

    /// Add a site to a trip
    public func addSite(tripId: String, siteId: String) throws {
        let _: Void = try database.write { db in
            // Get current max sort order
            let maxOrder: Int? = try TripSite
                .filter(TripSite.Columns.tripId == tripId)
                .select(max(TripSite.Columns.sortOrder))
                .fetchOne(db)

            let tripSite = TripSite(
                tripId: tripId,
                siteId: siteId,
                sortOrder: (maxOrder ?? -1) + 1
            )
            try tripSite.insert(db)
        }
    }

    /// Remove a site from a trip
    public func removeSite(tripId: String, siteId: String) throws {
        _ = try database.write { db in
            try TripSite
                .filter(TripSite.Columns.tripId == tripId)
                .filter(TripSite.Columns.siteId == siteId)
                .deleteAll(db)
        }
    }

    // MARK: - Delete

    public func delete(id: String) throws {
        try database.write { db in
            // Delete trip sites first (cascade)
            try TripSite
                .filter(TripSite.Columns.tripId == id)
                .deleteAll(db)

            // Delete trip
            try Trip.deleteOne(db, key: id)
        }
    }

    // MARK: - Async Methods

    public func getAllTrips() async throws -> [Trip] {
        try database.read { db in
            try Trip
                .order(Trip.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    public func getTripWithSites(tripId: String) async throws -> (Trip, [DiveSite])? {
        try database.read { db in
            guard let trip = try Trip.fetchOne(db, key: tripId) else { return nil }

            let sites = try DiveSite.fetchAll(db, sql: """
                SELECT s.* FROM dive_sites s
                INNER JOIN trip_sites ts ON ts.site_id = s.id
                WHERE ts.trip_id = ?
                ORDER BY ts.sort_order ASC
                """, arguments: [tripId])

            return (trip, sites)
        }
    }

    // MARK: - Statistics

    public func count() throws -> Int {
        try database.read { db in
            try Trip.fetchCount(db)
        }
    }

    public func siteCount(tripId: String) throws -> Int {
        try database.read { db in
            try TripSite
                .filter(TripSite.Columns.tripId == tripId)
                .fetchCount(db)
        }
    }
}
