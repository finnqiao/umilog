import Foundation
import CoreLocation

/// A curated dive destination shown to first-time users for inspiration.
public struct FeaturedDestination: Identifiable {
    public let id: String
    public let regionId: String
    public let displayName: String
    public let tagline: String
    public let coordinate: CLLocationCoordinate2D
    public let zoomLevel: Double

    public init(
        id: String = UUID().uuidString,
        regionId: String,
        displayName: String,
        tagline: String,
        latitude: Double,
        longitude: Double,
        zoomLevel: Double = 6.0
    ) {
        self.id = id
        self.regionId = regionId
        self.displayName = displayName
        self.tagline = tagline
        self.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        self.zoomLevel = zoomLevel
    }
}

// MARK: - Curated Destinations

extension FeaturedDestination {
    /// Curated list of photogenic dive regions with high site density.
    /// Rotates daily to provide "inspire my next trip" experience.
    public static let curated: [FeaturedDestination] = [
        FeaturedDestination(
            regionId: "red-sea-egypt",
            displayName: "Red Sea, Egypt",
            tagline: "Crystal waters and legendary wrecks",
            latitude: 27.2,
            longitude: 34.0,
            zoomLevel: 6.5
        ),
        FeaturedDestination(
            regionId: "coral-triangle",
            displayName: "Raja Ampat, Indonesia",
            tagline: "Biodiversity capital of the world",
            latitude: -0.5,
            longitude: 130.5,
            zoomLevel: 7.0
        ),
        FeaturedDestination(
            regionId: "great-barrier-reef",
            displayName: "Great Barrier Reef",
            tagline: "The world's largest coral reef system",
            latitude: -18.3,
            longitude: 147.7,
            zoomLevel: 5.5
        ),
        FeaturedDestination(
            regionId: "caribbean-mexico",
            displayName: "Riviera Maya, Mexico",
            tagline: "Cenotes, reefs, and whale sharks",
            latitude: 20.5,
            longitude: -87.4,
            zoomLevel: 7.0
        ),
        FeaturedDestination(
            regionId: "maldives",
            displayName: "Maldives",
            tagline: "Manta rays and pristine atolls",
            latitude: 3.2,
            longitude: 73.2,
            zoomLevel: 6.0
        ),
        FeaturedDestination(
            regionId: "philippines",
            displayName: "Philippines",
            tagline: "World-class macro and thresher sharks",
            latitude: 9.8,
            longitude: 124.0,
            zoomLevel: 6.5
        ),
        FeaturedDestination(
            regionId: "thailand",
            displayName: "Gulf of Thailand",
            tagline: "Tropical diving for all levels",
            latitude: 9.5,
            longitude: 100.0,
            zoomLevel: 7.0
        )
    ]
}
