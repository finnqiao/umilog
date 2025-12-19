import Foundation

/// Handles persistence of map state to UserDefaults.
final class MapStatePersistence {
    static let shared = MapStatePersistence()

    private let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let exploreFilters = "map.exploreFilters"
        static let filterLens = "map.filterLens"
        static let cameraLat = "map.camera.lat"
        static let cameraLon = "map.camera.lon"
        static let cameraZoom = "map.camera.zoom"
    }

    private init() {}

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

    func saveCamera(lat: Double, lon: Double, zoom: Double) {
        defaults.set(lat, forKey: Keys.cameraLat)
        defaults.set(lon, forKey: Keys.cameraLon)
        defaults.set(zoom, forKey: Keys.cameraZoom)
    }

    func loadCamera() -> (lat: Double, lon: Double, zoom: Double)? {
        guard defaults.object(forKey: Keys.cameraLat) != nil else { return nil }

        let lat = defaults.double(forKey: Keys.cameraLat)
        let lon = defaults.double(forKey: Keys.cameraLon)
        let zoom = defaults.double(forKey: Keys.cameraZoom)

        // Validate reasonable values
        guard lat >= -90 && lat <= 90 &&
              lon >= -180 && lon <= 180 &&
              zoom > 0 else {
            return nil
        }

        return (lat, lon, zoom)
    }

    func clearCamera() {
        defaults.removeObject(forKey: Keys.cameraLat)
        defaults.removeObject(forKey: Keys.cameraLon)
        defaults.removeObject(forKey: Keys.cameraZoom)
    }

    // MARK: - Reset All

    func resetAll() {
        defaults.removeObject(forKey: Keys.exploreFilters)
        defaults.removeObject(forKey: Keys.filterLens)
        clearCamera()
    }
}
