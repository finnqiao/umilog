import Foundation
import GRDB

/// Top-level geographic grouping of dive regions (e.g., "Coral Triangle", "Red Sea")
public struct RegionGroup: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let tagline: String?
    public let description: String?
    public let latitude: Double?
    public let longitude: Double?
    public let coverImageUrl: String?
    public let sortOrder: Int

    public init(
        id: String,
        name: String,
        tagline: String? = nil,
        description: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        coverImageUrl: String? = nil,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.tagline = tagline
        self.description = description
        self.latitude = latitude
        self.longitude = longitude
        self.coverImageUrl = coverImageUrl
        self.sortOrder = sortOrder
    }
}

// MARK: - GRDB
extension RegionGroup: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "region_groups"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let tagline = Column(CodingKeys.tagline)
        static let description = Column(CodingKeys.description)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let coverImageUrl = Column(CodingKeys.coverImageUrl)
        static let sortOrder = Column(CodingKeys.sortOrder)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case tagline
        case description
        case latitude
        case longitude
        case coverImageUrl = "cover_image_url"
        case sortOrder = "sort_order"
    }
}

// MARK: - Associations
extension RegionGroup {
    public static let regions = hasMany(Region.self, using: ForeignKey(["group_id"]))
}
