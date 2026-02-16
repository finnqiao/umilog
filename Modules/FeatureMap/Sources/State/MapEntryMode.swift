import Foundation

/// The entry mode determines initial map behavior and bottom shelf content.
///
/// - `explore`: Default mode showing global/curated/history content. Never requires location.
/// - `trips`: Shows user's trip regions and planned destinations.
/// - `nearMe`: GPS-based mode showing nearby sites. Optional, never default.
enum MapEntryMode: String, Codable, CaseIterable, Identifiable {
    case explore
    case trips
    case nearMe

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explore: return "Explore"
        case .trips: return "Trips"
        case .nearMe: return "Near me"
        }
    }

    var iconName: String {
        switch self {
        case .explore: return "globe"
        case .trips: return "suitcase"
        case .nearMe: return "location"
        }
    }

    /// Description shown in empty states or tooltips.
    var description: String {
        switch self {
        case .explore:
            return "Discover dive sites around the world"
        case .trips:
            return "Your planned and past dive trips"
        case .nearMe:
            return "Dive sites near your current location"
        }
    }
}
