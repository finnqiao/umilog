import Foundation
import MapLibre
import CoreLocation

/// A downloadable offline map region aligned to UmiLog's dive regions.
public struct OfflineRegion: Identifiable, Codable, Equatable {
    public let id: String
    public let name: String
    public let minLatitude: Double
    public let maxLatitude: Double
    public let minLongitude: Double
    public let maxLongitude: Double
    public let minZoom: Double
    public let maxZoom: Double
    public let siteCount: Int

    public var bounds: MLNCoordinateBounds {
        MLNCoordinateBounds(
            sw: CLLocationCoordinate2D(latitude: minLatitude, longitude: minLongitude),
            ne: CLLocationCoordinate2D(latitude: maxLatitude, longitude: maxLongitude)
        )
    }

    public var center: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )
    }
}

// MARK: - Predefined Regions

extension OfflineRegion {
    /// Predefined offline regions aligned to UmiLog's dive region seeds.
    /// Bounding boxes cover the site clusters within each region.
    public static let allRegions: [OfflineRegion] = [
        OfflineRegion(
            id: "red-sea",
            name: "Red Sea",
            minLatitude: 12.0, maxLatitude: 30.5,
            minLongitude: 32.0, maxLongitude: 44.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0  // populated at runtime from DB
        ),
        OfflineRegion(
            id: "southeast-asia",
            name: "Southeast Asia",
            minLatitude: -11.0, maxLatitude: 21.0,
            minLongitude: 95.0, maxLongitude: 130.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "caribbean",
            name: "Caribbean",
            minLatitude: 10.0, maxLatitude: 27.0,
            minLongitude: -90.0, maxLongitude: -59.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "pacific-islands",
            name: "Pacific Islands",
            minLatitude: -50.0, maxLatitude: 25.0,
            minLongitude: 150.0, maxLongitude: -150.0,
            minZoom: 4, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "mediterranean",
            name: "Mediterranean",
            minLatitude: 30.0, maxLatitude: 46.0,
            minLongitude: -6.0, maxLongitude: 37.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "indian-ocean",
            name: "Indian Ocean",
            minLatitude: -15.0, maxLatitude: 15.0,
            minLongitude: 39.0, maxLongitude: 80.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "japan",
            name: "Japan",
            minLatitude: 24.0, maxLatitude: 46.0,
            minLongitude: 122.0, maxLongitude: 146.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "australia",
            name: "Australia",
            minLatitude: -45.0, maxLatitude: -10.0,
            minLongitude: 112.0, maxLongitude: 155.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "atlantic",
            name: "Atlantic",
            minLatitude: 28.0, maxLatitude: 65.0,
            minLongitude: -30.0, maxLongitude: 5.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "africa",
            name: "Africa",
            minLatitude: -35.0, maxLatitude: 5.0,
            minLongitude: 10.0, maxLongitude: 52.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "central-america",
            name: "Central America",
            minLatitude: 7.0, maxLatitude: 23.0,
            minLongitude: -92.0, maxLongitude: -77.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
        OfflineRegion(
            id: "south-america",
            name: "South America",
            minLatitude: -55.0, maxLatitude: 13.0,
            minLongitude: -82.0, maxLongitude: -34.0,
            minZoom: 5, maxZoom: 14,
            siteCount: 0
        ),
    ]
}
