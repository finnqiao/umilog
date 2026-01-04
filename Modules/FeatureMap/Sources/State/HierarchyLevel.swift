import Foundation

/// Represents the current drill-down level in the map hierarchy.
/// Full hierarchy: World → Country → Region → Area
enum HierarchyLevel: Equatable, Hashable {
    case world
    case country(String)
    case region(countryId: String?, regionId: String)
    case area(regionId: String, areaId: String)

    /// Navigate one level up in the hierarchy.
    /// Returns nil if already at world level.
    var parent: HierarchyLevel? {
        switch self {
        case .world:
            return nil
        case .country:
            return .world
        case .region(let countryId, _):
            if let countryId = countryId {
                return .country(countryId)
            }
            return .world
        case .area(let regionId, _):
            return .region(countryId: nil, regionId: regionId)
        }
    }

    /// Returns the breadcrumb path as an array of display names.
    var breadcrumbPath: [String] {
        switch self {
        case .world:
            return []
        case .country(let countryId):
            return [countryId]
        case .region(let countryId, let regionId):
            if let countryId = countryId {
                return [countryId, regionId]
            }
            return [regionId]
        case .area(let regionId, let areaId):
            return [regionId, areaId]
        }
    }

    /// Whether this level is the root world view.
    var isWorld: Bool {
        if case .world = self { return true }
        return false
    }

    /// Whether this level is at country view.
    var isCountry: Bool {
        if case .country = self { return true }
        return false
    }

    /// Extract the country ID if at country, region, or area level.
    var countryId: String? {
        switch self {
        case .world:
            return nil
        case .country(let id):
            return id
        case .region(let countryId, _):
            return countryId
        case .area:
            return nil
        }
    }

    /// Extract the region ID if at region or area level.
    var regionId: String? {
        switch self {
        case .world, .country:
            return nil
        case .region(_, let id):
            return id
        case .area(let regionId, _):
            return regionId
        }
    }

    /// Extract the area ID if at area level.
    var areaId: String? {
        if case .area(_, let areaId) = self {
            return areaId
        }
        return nil
    }
}
