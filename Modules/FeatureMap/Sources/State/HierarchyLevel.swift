import Foundation

/// Represents the current drill-down level in the map hierarchy.
/// Replaces the previous `tier`, `selectedRegion`, `selectedArea` pattern.
enum HierarchyLevel: Equatable, Hashable {
    case world
    case region(String)
    case area(regionId: String, areaId: String)

    /// Navigate one level up in the hierarchy.
    /// Returns nil if already at world level.
    var parent: HierarchyLevel? {
        switch self {
        case .world:
            return nil
        case .region:
            return .world
        case .area(let regionId, _):
            return .region(regionId)
        }
    }

    /// Returns the breadcrumb path as an array of display names.
    /// World level returns empty array, region returns [regionName], area returns [regionId, areaId].
    var breadcrumbPath: [String] {
        switch self {
        case .world:
            return []
        case .region(let regionId):
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

    /// Extract the region ID if at region or area level.
    var regionId: String? {
        switch self {
        case .world:
            return nil
        case .region(let id):
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
