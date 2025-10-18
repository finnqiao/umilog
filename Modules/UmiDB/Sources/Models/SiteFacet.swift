import Foundation
import GRDB

/// Precomputed facets and metadata for a dive site (v4 schema)
public struct SiteFacet: Codable, Identifiable {
    public let id: String  // Matches site_id
    public let difficulty: String  // beginner, intermediate, advanced
    public let entryModes: [String]  // ["boat", "shore", "liveaboard"]
    public let notableFeatures: [String]  // ["wreck", "drift", "sharks"]
    public let visibilityMean: Double?  // meters
    public let tempMean: Double?  // Celsius
    public let seasonalityJson: String?  // {"peakMonths": ["Mar", "Apr", "May"]}
    public let shopCount: Int
    public let imageAssetIds: [String]  // ["image_uuid_1.jpg", ...]
    public let hasCurrent: Bool
    public let minDepth: Double?
    public let maxDepth: Double?
    public let isBeginner: Bool
    public let isAdvanced: Bool
    public let updatedAt: Date
    
    public init(
        id: String,
        difficulty: String,
        entryModes: [String] = [],
        notableFeatures: [String] = [],
        visibilityMean: Double? = nil,
        tempMean: Double? = nil,
        seasonalityJson: String? = nil,
        shopCount: Int = 0,
        imageAssetIds: [String] = [],
        hasCurrent: Bool = false,
        minDepth: Double? = nil,
        maxDepth: Double? = nil,
        isBeginner: Bool = false,
        isAdvanced: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.difficulty = difficulty
        self.entryModes = entryModes
        self.notableFeatures = notableFeatures
        self.visibilityMean = visibilityMean
        self.tempMean = tempMean
        self.seasonalityJson = seasonalityJson
        self.shopCount = shopCount
        self.imageAssetIds = imageAssetIds
        self.hasCurrent = hasCurrent
        self.minDepth = minDepth
        self.maxDepth = maxDepth
        self.isBeginner = isBeginner
        self.isAdvanced = isAdvanced
        self.updatedAt = updatedAt
    }
}

// MARK: - GRDB
extension SiteFacet: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "site_facets"
    
    public enum Columns {
        static let id = Column("site_id")
        static let difficulty = Column(CodingKeys.difficulty)
        static let entryModes = Column("entry_modes")
        static let notableFeatures = Column("notable_features")
        static let visibilityMean = Column("visibility_mean")
        static let tempMean = Column("temp_mean")
        static let seasonalityJson = Column("seasonality_json")
        static let shopCount = Column("shop_count")
        static let imageAssetIds = Column("image_asset_ids")
        static let hasCurrent = Column("has_current")
        static let minDepth = Column("min_depth")
        static let maxDepth = Column("max_depth")
        static let isBeginner = Column("is_beginner")
        static let isAdvanced = Column("is_advanced")
        static let updatedAt = Column("updated_at")
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case difficulty
        case entryModes
        case notableFeatures
        case visibilityMean
        case tempMean
        case seasonalityJson
        case shopCount
        case imageAssetIds
        case hasCurrent
        case minDepth
        case maxDepth
        case isBeginner
        case isAdvanced
        case updatedAt
    }
}