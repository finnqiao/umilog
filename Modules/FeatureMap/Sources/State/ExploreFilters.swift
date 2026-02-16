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

    // MARK: - Resy-Style Dive Filters

    /// Time period filter for logged dives.
    var timePeriod: TimePeriod

    /// Entry type filter (shore/boat).
    var entryType: Set<EntryType>

    /// Depth range presets.
    var depthRanges: Set<DepthRange>

    /// Default filters with nothing active.
    static let `default` = ExploreFilters(
        difficulty: [],
        siteType: [],
        showShops: true,
        maxDepthRange: nil,
        timePeriod: .allTime,
        entryType: [],
        depthRanges: []
    )

    /// Whether any filter is currently active.
    var isActive: Bool {
        !difficulty.isEmpty ||
        !siteType.isEmpty ||
        !showShops ||
        maxDepthRange != nil ||
        timePeriod != .allTime ||
        !entryType.isEmpty ||
        !depthRanges.isEmpty
    }

    /// Count of active filter categories.
    var activeCount: Int {
        var count = 0
        if !difficulty.isEmpty { count += 1 }
        if !siteType.isEmpty { count += 1 }
        if !showShops { count += 1 }
        if maxDepthRange != nil { count += 1 }
        if timePeriod != .allTime { count += 1 }
        if !entryType.isEmpty { count += 1 }
        if !depthRanges.isEmpty { count += 1 }
        return count
    }

    /// Reset all filters to default state.
    mutating func reset() {
        self = .default
    }
}

// MARK: - Time Period Filter

extension ExploreFilters {
    /// Time period for filtering logged dive sites.
    enum TimePeriod: String, Codable, CaseIterable, Hashable {
        case last30Days = "Last 30 days"
        case thisTrip = "This trip"
        case thisYear = "This year"
        case allTime = "All time"

        var dateThreshold: Date? {
            let calendar = Calendar.current
            switch self {
            case .last30Days:
                return calendar.date(byAdding: .day, value: -30, to: Date())
            case .thisYear:
                return calendar.date(from: calendar.dateComponents([.year], from: Date()))
            case .thisTrip, .allTime:
                return nil
            }
        }
    }
}

// MARK: - Entry Type Filter

extension ExploreFilters {
    /// Entry type for dive sites.
    enum EntryType: String, Codable, CaseIterable, Hashable {
        case shore = "Shore"
        case boat = "Boat"
    }
}

// MARK: - Depth Range Presets

extension ExploreFilters {
    /// Depth range presets for quick filtering.
    enum DepthRange: String, Codable, CaseIterable, Hashable {
        case shallow = "0-10m"
        case medium = "10-20m"
        case deep = "20-30m"
        case veryDeep = "30-40m"
        case technical = "40m+"

        var range: ClosedRange<Double> {
            switch self {
            case .shallow: return 0...10
            case .medium: return 10...20
            case .deep: return 20...30
            case .veryDeep: return 30...40
            case .technical: return 40...200
            }
        }

        /// Check if a depth value falls within this range.
        func contains(_ depth: Double) -> Bool {
            range.contains(depth)
        }
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
        case timePeriod
        case entryType
        case depthRanges
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

        // New Resy-style filters with backwards-compatible defaults
        timePeriod = try container.decodeIfPresent(TimePeriod.self, forKey: .timePeriod) ?? .allTime
        entryType = try container.decodeIfPresent(Set<EntryType>.self, forKey: .entryType) ?? []
        depthRanges = try container.decodeIfPresent(Set<DepthRange>.self, forKey: .depthRanges) ?? []
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

        // New Resy-style filters
        try container.encode(timePeriod, forKey: .timePeriod)
        try container.encode(entryType, forKey: .entryType)
        try container.encode(depthRanges, forKey: .depthRanges)
    }
}
