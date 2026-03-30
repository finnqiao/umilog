import Foundation
import MapKit

/// Semantic zoom level that determines what objects the map displays.
///
/// The map shows different types of content at each level:
/// - `.world`: Destination markers (regions like Red Sea, Philippines)
/// - `.regional`: Area markers with names and counts (Moalboal · 46)
/// - `.local`: Individual site pins with difficulty and status
enum MapZoomLevel: Equatable, Hashable {
    case world
    case regional
    case local

    /// Compute the semantic zoom level from a map region's latitude span.
    /// - Parameter latitudeDelta: The latitude span of the visible map region.
    /// - Returns: The appropriate zoom level for that span.
    static func from(latitudeDelta: Double) -> MapZoomLevel {
        if latitudeDelta > 20 {
            return .world
        } else if latitudeDelta > 3 {
            return .regional
        } else {
            return .local
        }
    }

    /// Compute from an MKCoordinateRegion.
    static func from(region: MKCoordinateRegion) -> MapZoomLevel {
        from(latitudeDelta: region.span.latitudeDelta)
    }

    /// Display name for the current zoom level (used in sheet titles).
    var displayName: String {
        switch self {
        case .world: return "Destinations"
        case .regional: return "Areas"
        case .local: return "Sites"
        }
    }

    /// SF Symbol icon for the zoom level.
    var iconName: String {
        switch self {
        case .world: return "globe"
        case .regional: return "map"
        case .local: return "mappin.and.ellipse"
        }
    }
}
