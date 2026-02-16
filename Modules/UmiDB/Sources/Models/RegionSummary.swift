import Foundation
import CoreLocation

/// Lightweight region info for UI display in fallback content and region chips.
/// Pre-computed data for fast rendering without database joins.
public struct RegionSummary: Identifiable, Hashable {
    public let id: String
    public let name: String
    public let countryName: String
    public let siteCount: Int
    public let imageURL: URL?
    public let centerLat: Double
    public let centerLon: Double
    public let zoomLevel: Double

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
    }

    public init(
        id: String,
        name: String,
        countryName: String,
        siteCount: Int,
        imageURL: URL? = nil,
        centerLat: Double,
        centerLon: Double,
        zoomLevel: Double = 7.0
    ) {
        self.id = id
        self.name = name
        self.countryName = countryName
        self.siteCount = siteCount
        self.imageURL = imageURL
        self.centerLat = centerLat
        self.centerLon = centerLon
        self.zoomLevel = zoomLevel
    }
}

// MARK: - Popular Regions

extension RegionSummary {
    /// Curated list of popular dive regions with high site density.
    /// Used as fallback when database regions are unavailable.
    public static let popular: [RegionSummary] = [
        RegionSummary(
            id: "caribbean",
            name: "Caribbean",
            countryName: "Multiple",
            siteCount: 500,
            centerLat: 18.0,
            centerLon: -70.0,
            zoomLevel: 5.0
        ),
        RegionSummary(
            id: "red-sea-egypt",
            name: "Red Sea",
            countryName: "Egypt",
            siteCount: 200,
            centerLat: 27.2,
            centerLon: 34.0,
            zoomLevel: 6.5
        ),
        RegionSummary(
            id: "florida-keys",
            name: "Florida Keys",
            countryName: "USA",
            siteCount: 150,
            centerLat: 24.6,
            centerLon: -81.4,
            zoomLevel: 8.0
        ),
        RegionSummary(
            id: "hawaii",
            name: "Hawaii",
            countryName: "USA",
            siteCount: 100,
            centerLat: 20.8,
            centerLon: -156.3,
            zoomLevel: 7.0
        ),
        RegionSummary(
            id: "philippines",
            name: "Philippines",
            countryName: "Philippines",
            siteCount: 300,
            centerLat: 9.8,
            centerLon: 124.0,
            zoomLevel: 6.0
        ),
        RegionSummary(
            id: "coral-triangle",
            name: "Indonesia",
            countryName: "Indonesia",
            siteCount: 400,
            centerLat: -0.5,
            centerLon: 130.5,
            zoomLevel: 5.5
        ),
        RegionSummary(
            id: "mediterranean",
            name: "Mediterranean",
            countryName: "Multiple",
            siteCount: 250,
            centerLat: 38.0,
            centerLon: 15.0,
            zoomLevel: 5.0
        ),
    ]
}
