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

    /// SF Symbol for empty state display.
    var emptyStateIcon: String {
        switch self {
        case .saved:
            return "star.slash"
        case .logged:
            return "waveform.path.ecg"
        case .planned:
            return "calendar.badge.plus"
        }
    }

    /// Title for the empty state when no sites match this lens.
    var emptyStateTitle: String {
        switch self {
        case .saved:
            return "No saved sites yet"
        case .logged:
            return "No logged dives yet"
        case .planned:
            return "No planned dives yet"
        }
    }

    /// Message for the empty state when no sites match this lens.
    var emptyStateMessage: String {
        switch self {
        case .saved:
            return "Tap the star on any dive site to save it to your wishlist."
        case .logged:
            return "Log your first dive to see your visited sites here."
        case .planned:
            return "Add dive sites to a trip plan to see them here."
        }
    }
}
