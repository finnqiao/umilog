import Foundation

/// Lightweight site payload for map rendering (minimal fields)
public struct SiteLite: Codable, Identifiable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    public let difficulty: String  // beginner, intermediate, advanced
    public let type: String  // Reef, Wreck, Wall, Cave, Shore, Drift
    public let tags: [String]  // Subset of top tags
    public let region: String
    public let visitedCount: Int
    public let wishlist: Bool
    
    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        difficulty: String,
        type: String,
        tags: [String] = [],
        region: String,
        visitedCount: Int = 0,
        wishlist: Bool = false
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.difficulty = difficulty
        self.type = type
        self.tags = tags
        self.region = region
        self.visitedCount = visitedCount
        self.wishlist = wishlist
    }
}