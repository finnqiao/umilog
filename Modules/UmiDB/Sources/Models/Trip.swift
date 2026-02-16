import Foundation
import GRDB

/// A planned diving trip containing multiple sites
public struct Trip: Codable, Identifiable {
    public let id: String
    public var name: String
    public var startDate: Date?
    public var endDate: Date?
    public var notes: String?
    public var coverImageUrl: String?
    public var calendarEventId: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: String = UUID().uuidString,
        name: String,
        startDate: Date? = nil,
        endDate: Date? = nil,
        notes: String? = nil,
        coverImageUrl: String? = nil,
        calendarEventId: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.coverImageUrl = coverImageUrl
        self.calendarEventId = calendarEventId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startDate = "start_date"
        case endDate = "end_date"
        case notes
        case coverImageUrl = "cover_image_url"
        case calendarEventId = "calendar_event_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - GRDB
extension Trip: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "trips"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let startDate = Column(CodingKeys.startDate)
        static let endDate = Column(CodingKeys.endDate)
        static let notes = Column(CodingKeys.notes)
        static let coverImageUrl = Column(CodingKeys.coverImageUrl)
        static let calendarEventId = Column(CodingKeys.calendarEventId)
        static let createdAt = Column(CodingKeys.createdAt)
        static let updatedAt = Column(CodingKeys.updatedAt)
    }
}

// MARK: - Associations
extension Trip {
    public static let tripSites = hasMany(TripSite.self)
    public static let sites = hasMany(DiveSite.self, through: tripSites, using: TripSite.site)
}
