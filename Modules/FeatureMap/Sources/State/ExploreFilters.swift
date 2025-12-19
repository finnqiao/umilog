import Foundation
import UmiDB

/// Filters for explore mode that constrain which sites are visible.
/// Persisted to UserDefaults via Codable.
struct ExploreFilters: Equatable, Hashable, Codable {
    /// Filter by difficulty levels (empty = all).
    var difficulty: Set<DiveSite.Difficulty>

    /// Filter by site types (empty = all).
    var siteType: Set<DiveSite.SiteType>

    /// Whether to show dive shops on the map.
    var showShops: Bool

    /// Optional depth range filter in meters.
    var maxDepthRange: ClosedRange<Double>?

    /// Default filters with nothing active.
    static let `default` = ExploreFilters(
        difficulty: [],
        siteType: [],
        showShops: true,
        maxDepthRange: nil
    )

    /// Whether any filter is currently active.
    var isActive: Bool {
        !difficulty.isEmpty ||
        !siteType.isEmpty ||
        !showShops ||
        maxDepthRange != nil
    }

    /// Count of active filter categories.
    var activeCount: Int {
        var count = 0
        if !difficulty.isEmpty { count += 1 }
        if !siteType.isEmpty { count += 1 }
        if !showShops { count += 1 }
        if maxDepthRange != nil { count += 1 }
        return count
    }

    /// Reset all filters to default state.
    mutating func reset() {
        self = .default
    }
}

// MARK: - Codable for ClosedRange

extension ExploreFilters {
    enum CodingKeys: String, CodingKey {
        case difficulty
        case siteType
        case showShops
        case depthMin
        case depthMax
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try container.decode(Set<DiveSite.Difficulty>.self, forKey: .difficulty)
        siteType = try container.decode(Set<DiveSite.SiteType>.self, forKey: .siteType)
        showShops = try container.decode(Bool.self, forKey: .showShops)

        if let min = try container.decodeIfPresent(Double.self, forKey: .depthMin),
           let max = try container.decodeIfPresent(Double.self, forKey: .depthMax) {
            maxDepthRange = min...max
        } else {
            maxDepthRange = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(siteType, forKey: .siteType)
        try container.encode(showShops, forKey: .showShops)

        if let range = maxDepthRange {
            try container.encode(range.lowerBound, forKey: .depthMin)
            try container.encode(range.upperBound, forKey: .depthMax)
        }
    }
}
