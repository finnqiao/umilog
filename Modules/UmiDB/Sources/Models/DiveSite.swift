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
    public let visitedCount: Int
    public let createdAt: Date
    public let tags: [String]  // v3: Wildlife, features, conditions, activities, characteristics
    
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
        visitedCount: Int = 0,
        tags: [String] = [],
        createdAt: Date = Date()
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
        self.visitedCount = visitedCount
        self.tags = tags
        self.createdAt = createdAt
    }
    
    public enum Difficulty: String, Codable {
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case advanced = "Advanced"
    }
    
    public enum SiteType: String, Codable {
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
        static let visitedCount = Column(CodingKeys.visitedCount)
        static let tags = Column(CodingKeys.tags)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

// MARK: - Associations
extension DiveSite {
    public static let dives = hasMany(DiveLog.self)
}
