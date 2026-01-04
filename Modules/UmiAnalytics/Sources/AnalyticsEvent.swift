import Foundation

/// Defines analytics events tracked in UmiLog
public enum AnalyticsEvent {
    /// App launched
    case appLaunched(firstLaunch: Bool)

    /// Dive logged successfully
    case diveLogged(logType: LogType, hasSite: Bool)

    /// Site viewed in detail
    case siteViewed(siteId: String, fromSearch: Bool)

    /// Site saved to wishlist or planned
    case siteSaved(siteId: String, action: SaveAction)

    /// Map region drilled down
    case mapDrillDown(regionName: String)

    /// Species viewed
    case speciesViewed(speciesId: String)

    /// Search performed
    case searchPerformed(query: String, resultCount: Int)

    // MARK: - Nested Types

    public enum LogType: String {
        case quick
        case live
    }

    public enum SaveAction: String {
        case wishlist
        case planned
    }

    // MARK: - Event Properties

    /// Event name for tracking
    public var name: String {
        switch self {
        case .appLaunched: return "app_launched"
        case .diveLogged: return "dive_logged"
        case .siteViewed: return "site_viewed"
        case .siteSaved: return "site_saved"
        case .mapDrillDown: return "map_drill_down"
        case .speciesViewed: return "species_viewed"
        case .searchPerformed: return "search_performed"
        }
    }

    /// Event properties for tracking
    public var properties: [String: Any] {
        switch self {
        case .appLaunched(let firstLaunch):
            return ["first_launch": firstLaunch]
        case .diveLogged(let logType, let hasSite):
            return ["log_type": logType.rawValue, "has_site": hasSite]
        case .siteViewed(let siteId, let fromSearch):
            return ["site_id": siteId, "from_search": fromSearch]
        case .siteSaved(let siteId, let action):
            return ["site_id": siteId, "action": action.rawValue]
        case .mapDrillDown(let regionName):
            return ["region_name": regionName]
        case .speciesViewed(let speciesId):
            return ["species_id": speciesId]
        case .searchPerformed(let query, let resultCount):
            return ["query_length": query.count, "result_count": resultCount]
        }
    }
}
