import Foundation
import CoreLocation
import UmiDB

/// Result of resolving initial map position.
public struct InitialMapPosition {
    public let center: CLLocationCoordinate2D
    public let zoom: Double
    public let regionId: String?
    public let countryId: String?
    public let reason: LandingReason

    public init(
        center: CLLocationCoordinate2D,
        zoom: Double,
        regionId: String? = nil,
        countryId: String? = nil,
        reason: LandingReason
    ) {
        self.center = center
        self.zoom = zoom
        self.regionId = regionId
        self.countryId = countryId
        self.reason = reason
    }
}

/// Why we chose this initial position.
public enum LandingReason: String {
    case homeRegion
    case lastOceanView
    case featuredDestination
    case localeDefault
    case globalFallback
    case userLocation
}

/// Resolves the best initial map position based on user context.
/// Ensures users always see a populated map, even when inland.
@MainActor
public final class ColdStartResolver {
    private let persistence = MapStatePersistence.shared
    private let geographyRepository: GeographyRepository
    private let siteRepository: SiteRepository

    // Distance threshold for "inland" detection (100km)
    private let inlandThresholdKm: Double = 100

    // Default zoom levels
    private let regionZoom: Double = 7.0
    private let countryZoom: Double = 5.0
    private let globalZoom: Double = 3.0

    public init(database: AppDatabase = .shared) {
        self.geographyRepository = GeographyRepository(database: database)
        self.siteRepository = SiteRepository(database: database)
    }

    // MARK: - Public Interface

    /// Resolves the best starting position for the map.
    ///
    /// Priority order:
    /// 1. User's home region (if set)
    /// 2. Last meaningful ocean view (region with sites)
    /// 3. Featured destination (first-time users)
    /// 4. Locale-based default (US → Florida Keys)
    /// 5. Global fallback (curated destination)
    public func resolveInitialPosition(
        isFirstLaunch: Bool,
        featuredDestination: FeaturedDestination?
    ) async -> InitialMapPosition {
        // 1. Home region (user preference)
        if let position = await resolveHomeRegion() {
            return position
        }

        // 2. Last ocean view (returning user)
        if let position = await resolveLastOceanView() {
            return position
        }

        // 3. Featured destination (first-time user)
        if isFirstLaunch, let featured = featuredDestination {
            return InitialMapPosition(
                center: featured.coordinate,
                zoom: featured.zoomLevel,
                regionId: featured.regionId,
                countryId: nil,
                reason: .featuredDestination
            )
        }

        // 4. Locale-based default
        if let position = await resolveLocaleDefault() {
            return position
        }

        // 5. Global fallback
        return resolveGlobalFallback()
    }

    /// Determines if the user's location is "inland" (far from dive sites).
    public func isUserInland(_ location: CLLocation) async -> Bool {
        guard let nearestDistance = await distanceToNearestSite(from: location) else {
            return true // No sites in DB, consider inland
        }
        return nearestDistance > inlandThresholdKm
    }

    /// Returns the count of sites near a location.
    public func nearbySiteCount(location: CLLocation, radiusKm: Double = 50) async -> Int {
        do {
            let sites = try siteRepository.fetchNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusKm: radiusKm,
                limit: 100
            )
            return sites.count
        } catch {
            return 0
        }
    }

    /// Saves the current view as the "last ocean view" if it contains sites.
    public func saveOceanViewIfPopulated(
        regionId: String?,
        countryId: String?,
        zoom: Double,
        siteCount: Int
    ) {
        // Only save if there are sites visible
        guard siteCount > 0 else { return }

        // Only save if we have a meaningful region/country
        guard regionId != nil || countryId != nil else { return }

        persistence.saveLastOceanView(
            regionId: regionId,
            countryId: countryId,
            zoom: zoom
        )

        // Also track as recent region
        if let regionId {
            persistence.addRecentRegion(regionId)
        }
    }

    // MARK: - Resolution Helpers

    private func resolveHomeRegion() async -> InitialMapPosition? {
        guard let (regionId, countryId) = persistence.loadHomeRegion() else {
            return nil
        }

        // Try to get region bounds
        if let bounds = try? geographyRepository.fetchBounds(regionId: regionId) {
            return InitialMapPosition(
                center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLon),
                zoom: regionZoom,
                regionId: regionId,
                countryId: countryId,
                reason: .homeRegion
            )
        }

        // Fallback to country bounds
        if let bounds = try? geographyRepository.fetchBounds(countryId: countryId) {
            return InitialMapPosition(
                center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLon),
                zoom: countryZoom,
                regionId: regionId,
                countryId: countryId,
                reason: .homeRegion
            )
        }

        return nil
    }

    private func resolveLastOceanView() async -> InitialMapPosition? {
        guard let (regionId, countryId, zoom) = persistence.loadLastOceanView() else {
            return nil
        }

        // Try region bounds first
        if let regionId, let bounds = try? geographyRepository.fetchBounds(regionId: regionId) {
            return InitialMapPosition(
                center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLon),
                zoom: zoom,
                regionId: regionId,
                countryId: countryId,
                reason: .lastOceanView
            )
        }

        // Fallback to country bounds
        if let countryId, let bounds = try? geographyRepository.fetchBounds(countryId: countryId) {
            return InitialMapPosition(
                center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLon),
                zoom: zoom,
                regionId: regionId,
                countryId: countryId,
                reason: .lastOceanView
            )
        }

        return nil
    }

    private func resolveLocaleDefault() async -> InitialMapPosition? {
        let countryCode = Locale.current.region?.identifier ?? ""

        guard let defaultRegion = localeDefaults[countryCode] else {
            return nil
        }

        if let bounds = try? geographyRepository.fetchBounds(regionId: defaultRegion.regionId) {
            return InitialMapPosition(
                center: CLLocationCoordinate2D(latitude: bounds.centerLat, longitude: bounds.centerLon),
                zoom: defaultRegion.zoom,
                regionId: defaultRegion.regionId,
                countryId: nil,
                reason: .localeDefault
            )
        }

        // Use hardcoded coordinates if region not in DB
        return InitialMapPosition(
            center: defaultRegion.fallbackCoordinate,
            zoom: defaultRegion.zoom,
            regionId: defaultRegion.regionId,
            countryId: nil,
            reason: .localeDefault
        )
    }

    private func resolveGlobalFallback() -> InitialMapPosition {
        // Use a rotating curated destination as fallback
        let destinations = FeaturedDestination.curated
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        let index = dayOfYear % destinations.count
        let destination = destinations[index]

        return InitialMapPosition(
            center: destination.coordinate,
            zoom: destination.zoomLevel,
            regionId: destination.regionId,
            countryId: nil,
            reason: .globalFallback
        )
    }

    private func distanceToNearestSite(from location: CLLocation) async -> Double? {
        do {
            let sites = try siteRepository.fetchNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusKm: 500, // Search within 500km
                limit: 1
            )

            guard let nearest = sites.first else { return nil }

            let siteLocation = CLLocation(
                latitude: nearest.latitude,
                longitude: nearest.longitude
            )

            return location.distance(from: siteLocation) / 1000 // Convert to km
        } catch {
            return nil
        }
    }

    // MARK: - Locale Defaults

    private struct LocaleDefault {
        let regionId: String
        let fallbackCoordinate: CLLocationCoordinate2D
        let zoom: Double
    }

    /// Country-appropriate default regions.
    /// Maps ISO 3166-1 alpha-2 country codes to good starting regions.
    private let localeDefaults: [String: LocaleDefault] = [
        // Americas
        "US": LocaleDefault(
            regionId: "florida-keys",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 24.6, longitude: -81.4),
            zoom: 8.0
        ),
        "CA": LocaleDefault(
            regionId: "british-columbia",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 49.3, longitude: -123.7),
            zoom: 7.0
        ),
        "MX": LocaleDefault(
            regionId: "caribbean-mexico",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 20.5, longitude: -87.4),
            zoom: 7.0
        ),

        // Europe
        "GB": LocaleDefault(
            regionId: "red-sea-egypt",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 27.2, longitude: 34.0),
            zoom: 6.5
        ),
        "DE": LocaleDefault(
            regionId: "red-sea-egypt",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 27.2, longitude: 34.0),
            zoom: 6.5
        ),
        "FR": LocaleDefault(
            regionId: "mediterranean",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 43.3, longitude: 6.9),
            zoom: 7.0
        ),
        "ES": LocaleDefault(
            regionId: "canary-islands",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 28.1, longitude: -15.4),
            zoom: 7.5
        ),

        // Asia-Pacific
        "JP": LocaleDefault(
            regionId: "okinawa",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 26.3, longitude: 127.8),
            zoom: 7.5
        ),
        "AU": LocaleDefault(
            regionId: "great-barrier-reef",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: -18.3, longitude: 147.7),
            zoom: 5.5
        ),
        "NZ": LocaleDefault(
            regionId: "poor-knights",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: -35.5, longitude: 174.7),
            zoom: 8.0
        ),
        "SG": LocaleDefault(
            regionId: "tioman",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 2.8, longitude: 104.2),
            zoom: 8.0
        ),

        // Middle East
        "AE": LocaleDefault(
            regionId: "oman",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 23.6, longitude: 58.5),
            zoom: 7.0
        ),
        "EG": LocaleDefault(
            regionId: "red-sea-egypt",
            fallbackCoordinate: CLLocationCoordinate2D(latitude: 27.2, longitude: 34.0),
            zoom: 6.5
        ),
    ]
}
