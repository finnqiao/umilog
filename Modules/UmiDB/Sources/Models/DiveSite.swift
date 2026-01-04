import Foundation
import GRDB
import CoreLocation

/// Dive site location and details
public struct DiveSite: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let location: String
    public let latitude: Double
    public let longitude: Double
    public let region: String
    public let averageDepth: Double
    public let maxDepth: Double
    public let averageTemp: Double
    public let averageVisibility: Double
    public let difficulty: Difficulty
    public let type: SiteType
    public let description: String?
    public let wishlist: Bool
    public let isPlanned: Bool  // v6: Trip planning support
    public let visitedCount: Int
    public let createdAt: Date
    public let tags: [String]  // v3: Wildlife, features, conditions, activities, characteristics
    // v5: Geographic hierarchy foreign keys
    public let countryId: String?
    public let regionId: String?
    public let areaId: String?
    public let wikidataId: String?
    public let osmId: String?

    /// Computed property for MapKit compatibility
    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public init(
        id: String = UUID().uuidString,
        name: String,
        location: String,
        latitude: Double,
        longitude: Double,
        region: String,
        averageDepth: Double,
        maxDepth: Double,
        averageTemp: Double,
        averageVisibility: Double,
        difficulty: Difficulty = .intermediate,
        type: SiteType,
        description: String? = nil,
        wishlist: Bool = false,
        isPlanned: Bool = false,
        visitedCount: Int = 0,
        tags: [String] = [],
        createdAt: Date = Date(),
        countryId: String? = nil,
        regionId: String? = nil,
        areaId: String? = nil,
        wikidataId: String? = nil,
        osmId: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.latitude = latitude
        self.longitude = longitude
        self.region = region
        self.averageDepth = averageDepth
        self.maxDepth = maxDepth
        self.averageTemp = averageTemp
        self.averageVisibility = averageVisibility
        self.difficulty = difficulty
        self.type = type
        self.description = description
        self.wishlist = wishlist
        self.isPlanned = isPlanned
        self.visitedCount = visitedCount
        self.tags = tags
        self.createdAt = createdAt
        self.countryId = countryId
        self.regionId = regionId
        self.areaId = areaId
        self.wikidataId = wikidataId
        self.osmId = osmId
    }
    
    public enum Difficulty: String, Codable, CaseIterable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }

    public enum SiteType: String, Codable, CaseIterable {
        case reef = "Reef"
        case wreck = "Wreck"
        case wall = "Wall"
        case cave = "Cave"
        case shore = "Shore"
        case drift = "Drift"
    }
}

// MARK: - GRDB
extension DiveSite: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "sites"

    public enum Columns {
        static let id = Column(CodingKeys.id)
        static let name = Column(CodingKeys.name)
        static let location = Column(CodingKeys.location)
        static let latitude = Column(CodingKeys.latitude)
        static let longitude = Column(CodingKeys.longitude)
        static let region = Column(CodingKeys.region)
        static let averageDepth = Column(CodingKeys.averageDepth)
        static let maxDepth = Column(CodingKeys.maxDepth)
        static let averageTemp = Column(CodingKeys.averageTemp)
        static let averageVisibility = Column(CodingKeys.averageVisibility)
        static let difficulty = Column(CodingKeys.difficulty)
        static let type = Column(CodingKeys.type)
        static let description = Column(CodingKeys.description)
        static let wishlist = Column(CodingKeys.wishlist)
        static let isPlanned = Column(CodingKeys.isPlanned)
        static let visitedCount = Column(CodingKeys.visitedCount)
        static let tags = Column(CodingKeys.tags)
        static let createdAt = Column(CodingKeys.createdAt)
        // v5: Geographic hierarchy
        static let countryId = Column(CodingKeys.countryId)
        static let regionId = Column(CodingKeys.regionId)
        static let areaId = Column(CodingKeys.areaId)
        static let wikidataId = Column(CodingKeys.wikidataId)
        static let osmId = Column(CodingKeys.osmId)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, location, latitude, longitude, region
        case averageDepth, maxDepth, averageTemp, averageVisibility
        case difficulty, type, description, wishlist, isPlanned, visitedCount, tags, createdAt
        case countryId = "country_id"
        case regionId = "region_id"
        case areaId = "area_id"
        case wikidataId = "wikidata_id"
        case osmId = "osm_id"
    }
}

// MARK: - Associations
extension DiveSite {
    public static let dives = hasMany(DiveLog.self)
    public static let country = belongsTo(Country.self)
    public static let regionRef = belongsTo(Region.self)
    public static let area = belongsTo(Area.self)
    public static let speciesLinks = hasMany(SiteSpeciesLink.self)
}
