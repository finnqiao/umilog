import Foundation

/// Lightweight record of a recently viewed site for quick UI display.
public struct RecentlyViewedSite: Codable, Identifiable, Hashable {
    public let id: String
    public let name: String
    public let location: String
    public let region: String
    public let type: DiveSite.SiteType
    public let difficulty: DiveSite.Difficulty
    public let maxDepth: Double
    public let viewedAt: Date

    public init(
        id: String,
        name: String,
        location: String,
        region: String,
        type: DiveSite.SiteType,
        difficulty: DiveSite.Difficulty,
        maxDepth: Double,
        viewedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.region = region
        self.type = type
        self.difficulty = difficulty
        self.maxDepth = maxDepth
        self.viewedAt = viewedAt
    }

    public init(site: DiveSite, viewedAt: Date = Date()) {
        self.init(
            id: site.id,
            name: site.name,
            location: site.location,
            region: site.region,
            type: site.type,
            difficulty: site.difficulty,
            maxDepth: site.maxDepth,
            viewedAt: viewedAt
        )
    }
}
