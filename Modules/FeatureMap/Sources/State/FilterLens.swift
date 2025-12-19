import Foundation

/// Filter lens for "My Sites" functionality.
/// Applies a lens over the map to show only sites matching the user's relationship.
enum FilterLens: String, Equatable, Hashable, Codable, CaseIterable {
    case saved
    case logged
    case planned

    /// Human-readable display name for UI.
    var displayName: String {
        switch self {
        case .saved:
            return "Saved"
        case .logged:
            return "Logged"
        case .planned:
            return "Planned"
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
        }
    }
}
