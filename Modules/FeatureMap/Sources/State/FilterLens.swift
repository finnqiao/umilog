import Foundation

/// Filter lens for "My Sites" functionality.
/// Applies a lens over the map to show only sites matching the user's relationship.
enum FilterLens: String, Equatable, Hashable, Codable, CaseIterable {
    case saved
    case logged
    case planned
    case trip

    /// Human-readable display name for UI.
    var displayName: String {
        switch self {
        case .saved:
            return "Wishlist"
        case .logged:
            return "My Dives"
        case .planned:
            return "Planning"
        case .trip:
            return "Trip"
        }
    }

    /// SF Symbol name for the lens icon.
    var iconName: String {
        switch self {
        case .saved:
            return "star.fill"
        case .logged:
            return "checkmark.circle.fill"
        case .planned:
            return "calendar"
        case .trip:
            return "suitcase.fill"
        }
    }

    /// Tint color name for the lens (using design system color names).
    var colorName: String {
        switch self {
        case .saved:
            return "reef"
        case .logged:
            return "kelp"
        case .planned:
            return "oceanBlue"
        case .trip:
            return "amber"
        }
    }

    /// Quick filter lenses shown as chips in the sheet header.
    /// Excludes planned (redundant with trip) to keep the surface clean.
    static var quickFilters: [FilterLens] {
        [.logged, .saved, .trip]
    }
}
