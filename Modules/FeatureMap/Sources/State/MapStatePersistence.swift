import Foundation

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
        // Deprecated - no longer used for privacy reasons
        // static let cameraLat = "map.camera.lat"
        // static let cameraLon = "map.camera.lon"
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

    // MARK: - Reset All

    func resetAll() {
        defaults.removeObject(forKey: Keys.exploreFilters)
        defaults.removeObject(forKey: Keys.filterLens)
        clearCamera()
    }
}
