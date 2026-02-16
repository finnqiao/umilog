import Foundation
import UmiDB

/// Handles persistence of map state to UserDefaults.
///
/// Privacy note: GPS coordinates are intentionally NOT persisted to avoid
/// storing sensitive location data in UserDefaults. Only non-sensitive
/// preferences like filters and zoom level are stored.
final class MapStatePersistence {
    static let shared = MapStatePersistence()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let exploreFilters = "map.exploreFilters"
        static let filterLens = "map.filterLens"
        static let cameraZoom = "map.camera.zoom"
        static let hasLaunchedBefore = "map.hasLaunchedBefore"

        // Entry mode (explore/trips/nearMe)
        static let entryMode = "map.entryMode"

        // Last meaningful ocean view (privacy-safe: region ID, not GPS)
        static let lastOceanRegionId = "map.lastOceanRegion"
        static let lastOceanCountryId = "map.lastOceanCountry"
        static let lastOceanZoom = "map.lastOceanZoom"

        // User's home region preference
        static let homeRegionId = "map.homeRegion"
        static let homeCountryId = "map.homeCountry"

        // Recently viewed regions (JSON array of region IDs)
        static let recentRegionIds = "map.recentRegions"

        // Recently viewed sites (JSON array of RecentlyViewedSite)
        static let recentSites = "map.recentSites"
    }

    private init() {
        // Clean up any previously stored GPS coordinates
        migrateRemoveGPSData()
    }

    /// Removes any previously stored GPS coordinates (privacy migration)
    private func migrateRemoveGPSData() {
        defaults.removeObject(forKey: "map.camera.lat")
        defaults.removeObject(forKey: "map.camera.lon")
    }

    // MARK: - Explore Filters

    func saveExploreFilters(_ filters: ExploreFilters) {
        guard let data = try? JSONEncoder().encode(filters) else { return }
        defaults.set(data, forKey: Keys.exploreFilters)
    }

    func loadExploreFilters() -> ExploreFilters {
        guard let data = defaults.data(forKey: Keys.exploreFilters),
              let filters = try? JSONDecoder().decode(ExploreFilters.self, from: data) else {
            return .default
        }
        return filters
    }

    // MARK: - Filter Lens

    func saveFilterLens(_ lens: FilterLens) {
        defaults.set(lens.rawValue, forKey: Keys.filterLens)
    }

    func loadFilterLens() -> FilterLens? {
        guard let rawValue = defaults.string(forKey: Keys.filterLens) else { return nil }
        return FilterLens(rawValue: rawValue)
    }

    func clearFilterLens() {
        defaults.removeObject(forKey: Keys.filterLens)
    }

    // MARK: - Camera Position

    /// Saves only zoom level (lat/lon not persisted for privacy)
    func saveCamera(lat: Double, lon: Double, zoom: Double) {
        // Privacy: Only store zoom level, not GPS coordinates
        defaults.set(zoom, forKey: Keys.cameraZoom)
    }

    /// Returns nil as GPS coordinates are no longer persisted for privacy.
    /// Callers should use default map center instead.
    func loadCamera() -> (lat: Double, lon: Double, zoom: Double)? {
        // GPS coordinates are no longer stored for privacy reasons
        // Return nil so caller uses default map center
        return nil
    }

    /// Returns the last saved zoom level, if any
    func loadZoomLevel() -> Double? {
        let zoom = defaults.double(forKey: Keys.cameraZoom)
        return zoom > 0 ? zoom : nil
    }

    func clearCamera() {
        defaults.removeObject(forKey: Keys.cameraZoom)
    }

    // MARK: - First Launch

    var hasLaunchedBefore: Bool {
        get { defaults.bool(forKey: Keys.hasLaunchedBefore) }
        set { defaults.set(newValue, forKey: Keys.hasLaunchedBefore) }
    }

    // MARK: - Entry Mode

    func saveEntryMode(_ mode: MapEntryMode) {
        defaults.set(mode.rawValue, forKey: Keys.entryMode)
    }

    func loadEntryMode() -> MapEntryMode {
        guard let rawValue = defaults.string(forKey: Keys.entryMode),
              let mode = MapEntryMode(rawValue: rawValue) else {
            return .explore // Default
        }
        return mode
    }

    // MARK: - Last Ocean View

    /// Saves the last map view that contained dive sites (privacy-safe via region ID).
    func saveLastOceanView(regionId: String?, countryId: String?, zoom: Double) {
        if let regionId {
            defaults.set(regionId, forKey: Keys.lastOceanRegionId)
        } else {
            defaults.removeObject(forKey: Keys.lastOceanRegionId)
        }

        if let countryId {
            defaults.set(countryId, forKey: Keys.lastOceanCountryId)
        } else {
            defaults.removeObject(forKey: Keys.lastOceanCountryId)
        }

        defaults.set(zoom, forKey: Keys.lastOceanZoom)
    }

    /// Returns the last ocean view if available.
    func loadLastOceanView() -> (regionId: String?, countryId: String?, zoom: Double)? {
        let regionId = defaults.string(forKey: Keys.lastOceanRegionId)
        let countryId = defaults.string(forKey: Keys.lastOceanCountryId)
        let zoom = defaults.double(forKey: Keys.lastOceanZoom)

        // At least need a region or country to be useful
        guard regionId != nil || countryId != nil else { return nil }
        return (regionId, countryId, zoom > 0 ? zoom : 8.0)
    }

    func clearLastOceanView() {
        defaults.removeObject(forKey: Keys.lastOceanRegionId)
        defaults.removeObject(forKey: Keys.lastOceanCountryId)
        defaults.removeObject(forKey: Keys.lastOceanZoom)
    }

    // MARK: - Home Region

    /// Saves the user's preferred home region.
    func saveHomeRegion(regionId: String, countryId: String) {
        defaults.set(regionId, forKey: Keys.homeRegionId)
        defaults.set(countryId, forKey: Keys.homeCountryId)
    }

    /// Returns the user's home region if set.
    func loadHomeRegion() -> (regionId: String, countryId: String)? {
        guard let regionId = defaults.string(forKey: Keys.homeRegionId),
              let countryId = defaults.string(forKey: Keys.homeCountryId) else {
            return nil
        }
        return (regionId, countryId)
    }

    func clearHomeRegion() {
        defaults.removeObject(forKey: Keys.homeRegionId)
        defaults.removeObject(forKey: Keys.homeCountryId)
    }

    // MARK: - Recent Regions

    private let maxRecentRegions = 10

    /// Adds a region to the recently viewed list.
    func addRecentRegion(_ regionId: String) {
        var recent = loadRecentRegions()

        // Remove if already present (will re-add at front)
        recent.removeAll { $0 == regionId }

        // Add to front
        recent.insert(regionId, at: 0)

        // Trim to max
        if recent.count > maxRecentRegions {
            recent = Array(recent.prefix(maxRecentRegions))
        }

        // Save
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: Keys.recentRegionIds)
        }
    }

    /// Returns recently viewed region IDs (most recent first).
    func loadRecentRegions() -> [String] {
        guard let data = defaults.data(forKey: Keys.recentRegionIds),
              let ids = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return ids
    }

    func clearRecentRegions() {
        defaults.removeObject(forKey: Keys.recentRegionIds)
    }

    // MARK: - Recent Sites

    private let maxRecentSites = 20

    /// Adds a site to the recently viewed list.
    func addRecentSite(_ site: DiveSite) {
        var recent = loadRecentSites()
        let entry = RecentlyViewedSite(site: site)

        // Remove if already present (will re-add at front)
        recent.removeAll { $0.id == entry.id }

        // Add to front
        recent.insert(entry, at: 0)

        // Trim to max
        if recent.count > maxRecentSites {
            recent = Array(recent.prefix(maxRecentSites))
        }

        // Save
        if let data = try? JSONEncoder().encode(recent) {
            defaults.set(data, forKey: Keys.recentSites)
        }
    }

    /// Returns recently viewed sites (most recent first).
    func loadRecentSites() -> [RecentlyViewedSite] {
        guard let data = defaults.data(forKey: Keys.recentSites),
              let sites = try? JSONDecoder().decode([RecentlyViewedSite].self, from: data) else {
            return []
        }
        return sites
    }

    func clearRecentSites() {
        defaults.removeObject(forKey: Keys.recentSites)
    }

    // MARK: - Reset All

    func resetAll() {
        defaults.removeObject(forKey: Keys.exploreFilters)
        defaults.removeObject(forKey: Keys.filterLens)
        defaults.removeObject(forKey: Keys.entryMode)
        clearCamera()
        clearLastOceanView()
        clearHomeRegion()
        clearRecentRegions()
        clearRecentSites()
    }
}
