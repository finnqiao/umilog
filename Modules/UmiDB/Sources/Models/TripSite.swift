import Foundation
import GRDB

/// Junction table linking trips to dive sites with ordering
public struct TripSite: Codable {
    public let tripId: String
    public let siteId: String
    public var sortOrder: Int
    public var plannedDate: Date?
    public var notes: String?

    public init(
        tripId: String,
        siteId: String,
        sortOrder: Int = 0,
        plannedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.tripId = tripId
        self.siteId = siteId
        self.sortOrder = sortOrder
        self.plannedDate = plannedDate
        self.notes = notes
    }

    enum CodingKeys: String, CodingKey {
        case tripId = "trip_id"
        case siteId = "site_id"
        case sortOrder = "sort_order"
        case plannedDate = "planned_date"
        case notes
    }
}

// MARK: - GRDB
extension TripSite: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "trip_sites"

    public enum Columns {
        static let tripId = Column(CodingKeys.tripId)
        static let siteId = Column(CodingKeys.siteId)
        static let sortOrder = Column(CodingKeys.sortOrder)
        static let plannedDate = Column(CodingKeys.plannedDate)
        static let notes = Column(CodingKeys.notes)
    }
}

// MARK: - Associations
extension TripSite {
    public static let trip = belongsTo(Trip.self)
    public static let site = belongsTo(DiveSite.self)
}
