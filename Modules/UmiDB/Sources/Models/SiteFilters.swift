import Foundation
import GRDB

/// Filters for site queries (viewport-aware)
public struct SiteFilters: Codable {
    public let tags: [String]
    public let difficulty: [String]
    public let features: [String]
    public let entryModes: [String]
    public let minVisibility: Double?
    public let maxTemp: Double?
    public let services: [String]
    public let hasCurrent: Bool?
    public let wildlife: [String]
    
    public init(
        tags: [String] = [],
        difficulty: [String] = [],
        features: [String] = [],
        entryModes: [String] = [],
        minVisibility: Double? = nil,
        maxTemp: Double? = nil,
        services: [String] = [],
        hasCurrent: Bool? = nil,
        wildlife: [String] = []
    ) {
        self.tags = tags
        self.difficulty = difficulty
        self.features = features
        self.entryModes = entryModes
        self.minVisibility = minVisibility
        self.maxTemp = maxTemp
        self.services = services
        self.hasCurrent = hasCurrent
        self.wildlife = wildlife
    }
    
    public var isEmpty: Bool {
        tags.isEmpty && difficulty.isEmpty && features.isEmpty &&
        entryModes.isEmpty && minVisibility == nil && maxTemp == nil &&
        services.isEmpty && hasCurrent == nil && wildlife.isEmpty
    }
}

/// Precomputed filter counts (from materialized view)
public struct MaterializedFilter: Codable, Identifiable {
    public let id: String  // UUID for Identifiable
    public let region: String?
    public let area: String?
    public let facet: String  // "tag", "difficulty", "feature", "entry"
    public let value: String  // e.g., "wreck", "beginner"
    public let count: Int
    
    public init(
        region: String? = nil,
        area: String? = nil,
        facet: String,
        value: String,
        count: Int
    ) {
        self.id = UUID().uuidString
        self.region = region
        self.area = area
        self.facet = facet
        self.value = value
        self.count = count
    }
}

// MARK: - GRDB
extension MaterializedFilter: FetchableRecord {
    public static let databaseTableName = "site_filters_materialized"
    
    public enum Columns {
        static let region = Column(CodingKeys.region)
        static let area = Column(CodingKeys.area)
        static let facet = Column(CodingKeys.facet)
        static let value = Column(CodingKeys.value)
        static let count = Column(CodingKeys.count)
    }
}