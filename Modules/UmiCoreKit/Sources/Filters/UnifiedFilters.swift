import Foundation

/// Unified filter state shared across History and Map tabs.
/// Uses String-based enums to avoid circular dependency with UmiDB.
/// Persisted to UserDefaults via Codable.
public struct UnifiedFilters: Equatable, Hashable, Codable {
    /// Filter by difficulty levels (empty = all).
    /// Values: "Beginner", "Intermediate", "Advanced"
    public var difficulty: Set<String>

    /// Filter by site types (empty = all).
    /// Values: "Reef", "Wreck", "Wall", "Cave", "Shore", "Drift"
    public var siteType: Set<String>

    /// Filter lens for "My Sites" mode.
    public var lens: FilterLensType?

    /// Optional depth range filter in meters.
    public var maxDepthRange: ClosedRange<Double>?

    public init(
        difficulty: Set<String> = [],
        siteType: Set<String> = [],
        lens: FilterLensType? = nil,
        maxDepthRange: ClosedRange<Double>? = nil
    ) {
        self.difficulty = difficulty
        self.siteType = siteType
        self.lens = lens
        self.maxDepthRange = maxDepthRange
    }

    /// Default filters with nothing active.
    public static let `default` = UnifiedFilters()

    /// Whether any filter is currently active.
    public var isActive: Bool {
        !difficulty.isEmpty || !siteType.isEmpty || lens != nil || maxDepthRange != nil
    }

    /// Count of active filter categories.
    public var activeCount: Int {
        var count = 0
        if !difficulty.isEmpty { count += 1 }
        if !siteType.isEmpty { count += 1 }
        if lens != nil { count += 1 }
        if maxDepthRange != nil { count += 1 }
        return count
    }

    /// Reset all filters to default state.
    public mutating func reset() {
        self = .default
    }
}

// MARK: - Filter Lens Type

/// Lens type for filtering "My Sites" (saved, logged, planned).
public enum FilterLensType: String, Codable, CaseIterable, Identifiable {
    case saved
    case logged
    case planned

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .saved: return "Saved"
        case .logged: return "Logged"
        case .planned: return "Planned"
        }
    }

    public var iconName: String {
        switch self {
        case .saved: return "star.fill"
        case .logged: return "checkmark.circle.fill"
        case .planned: return "calendar"
        }
    }
}

// MARK: - Difficulty Helpers

public enum DifficultyLevel: String, CaseIterable, Identifiable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    public var id: String { rawValue }

    public var displayName: String { rawValue }
}

// MARK: - Site Type Helpers

public enum SiteTypeFilter: String, CaseIterable, Identifiable {
    case reef = "Reef"
    case wreck = "Wreck"
    case wall = "Wall"
    case cave = "Cave"
    case shore = "Shore"
    case drift = "Drift"

    public var id: String { rawValue }

    public var displayName: String { rawValue }

    public var iconName: String {
        switch self {
        case .reef: return "leaf.fill"
        case .wreck: return "ferry.fill"
        case .wall: return "square.stack.3d.up.fill"
        case .cave: return "mountain.2.fill"
        case .shore: return "beach.umbrella.fill"
        case .drift: return "wind"
        }
    }
}

// MARK: - Codable for ClosedRange

extension UnifiedFilters {
    enum CodingKeys: String, CodingKey {
        case difficulty
        case siteType
        case lens
        case depthMin
        case depthMax
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        difficulty = try container.decodeIfPresent(Set<String>.self, forKey: .difficulty) ?? []
        siteType = try container.decodeIfPresent(Set<String>.self, forKey: .siteType) ?? []
        lens = try container.decodeIfPresent(FilterLensType.self, forKey: .lens)

        if let min = try container.decodeIfPresent(Double.self, forKey: .depthMin),
           let max = try container.decodeIfPresent(Double.self, forKey: .depthMax) {
            maxDepthRange = min...max
        } else {
            maxDepthRange = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(difficulty, forKey: .difficulty)
        try container.encode(siteType, forKey: .siteType)
        try container.encodeIfPresent(lens, forKey: .lens)

        if let range = maxDepthRange {
            try container.encode(range.lowerBound, forKey: .depthMin)
            try container.encode(range.upperBound, forKey: .depthMax)
        }
    }
}
