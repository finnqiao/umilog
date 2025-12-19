import SwiftUI
import MapKit  // For MKCoordinateRegion/Span types
import CoreLocation  // For CLLocationCoordinate2D
import UmiDB
import DiveMap
import UmiCoreKit

// MARK: - Map Bounds

/// Represents a geographic bounding box for viewport queries.
/// Can be initialized from MKCoordinateRegion or DiveMapViewport.
struct MapBounds {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double

    init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    init(region: MKCoordinateRegion) {
        let span = region.span
        let center = region.center
        self.init(
            minLatitude: center.latitude - span.latitudeDelta / 2,
            maxLatitude: center.latitude + span.latitudeDelta / 2,
            minLongitude: center.longitude - span.longitudeDelta / 2,
            maxLongitude: center.longitude + span.longitudeDelta / 2
        )
    }

    init(viewport: DiveMapViewport) {
        self.init(
            minLatitude: viewport.minLatitude,
            maxLatitude: viewport.maxLatitude,
            minLongitude: viewport.minLongitude,
            maxLongitude: viewport.maxLongitude
        )
    }

    func toRegion() -> MKCoordinateRegion {
        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2.0,
            longitude: (minLongitude + maxLongitude) / 2.0
        )
        let minimumSpan: Double = 0.02  // ~2km to keep style tiles available
        let latitudeDelta = max(maxLatitude - minLatitude, minimumSpan)
        let longitudeDelta = max(maxLongitude - minLongitude, minimumSpan)
        let span = MKCoordinateSpan(
            latitudeDelta: latitudeDelta,
            longitudeDelta: longitudeDelta
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Map ViewModel

/// Manages map state including mode, filters, sites, and regions.
/// Persists filter preferences to UserDefaults.
@MainActor
class MapViewModel: ObservableObject {
    @Published var mode: MapMode {
        didSet {
            saveFilterPreferences()
        }
    }
    @Published var statusFilter: StatusFilter {
        didSet {
            saveFilterPreferences()
        }
    }
    @Published var exploreFilter: ExploreFilter {
        didSet {
            saveFilterPreferences()
        }
    }
    @Published var tier: Tier = .regions
    @Published var selectedRegion: Region?
    @Published var selectedArea: Area?
    @Published var layerSettings: MapLayerSettings = MapLayerSettings()

    @Published var sites: [DiveSite] = []
    @Published var shops: [MapDiveShop] = []
    @Published var regions: [Region] = []
    @Published var loading: Bool = false
    @Published var visibleSites: [DiveSite] = []

    private var wishlistObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private static let modeKey = "map.filter.mode"
    private static let statusFilterKey = "map.filter.status"
    private static let exploreFilterKey = "map.filter.explore"

    // MARK: - Map State Persistence (US-2)
    private static let lastCenterLatKey = "map.lastCenter.lat"
    private static let lastCenterLonKey = "map.lastCenter.lon"
    private static let lastZoomKey = "map.lastZoom"

    init() {
        // Load persisted filter preferences
        let savedMode = defaults.string(forKey: Self.modeKey) ?? "myMap"
        self.mode = savedMode == "explore" ? .explore : .myMap

        let savedStatusFilter = defaults.string(forKey: Self.statusFilterKey) ?? "wishlist"
        self.statusFilter = Self.parseStatusFilter(savedStatusFilter)

        let savedExploreFilter = defaults.string(forKey: Self.exploreFilterKey) ?? "all"
        self.exploreFilter = Self.parseExploreFilter(savedExploreFilter)

        wishlistObserver = NotificationCenter.default.addObserver(
            forName: .wishlistUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.applyWishlistUpdate(notification)
        }
    }

    deinit {
        if let wishlistObserver {
            NotificationCenter.default.removeObserver(wishlistObserver)
        }
    }

    var filteredSites: [DiveSite] {
        if mode == .myMap {
            return applyMyMapFilters(to: visibleSites)
        } else {
            return applyExploreFilters(to: visibleSites)
        }
    }

    func applyMyMapFilters(to sites: [DiveSite]) -> [DiveSite] {
        sites.filter { site in
            guard matchesHierarchy(site) else { return false }
            switch statusFilter {
            case .visited:
                return site.visitedCount > 0
            case .wishlist:
                return site.wishlist
            case .planned:
                return false // TODO: planned sites support
            }
        }
    }

    func applyExploreFilters(to sites: [DiveSite]) -> [DiveSite] {
        sites.filter { site in
            guard matchesHierarchy(site) else { return false }
            switch exploreFilter {
            case .all:
                return true
            case .nearby:
                return true // TODO: incorporate user location distance
            case .popular:
                return site.visitedCount > 5
            case .beginner:
                return site.difficulty == .beginner
            case .wrecks:
                return site.type == .wreck
            }
        }
    }

    private func matchesHierarchy(_ site: DiveSite) -> Bool {
        if let region = selectedRegion, site.region != region.name {
            return false
        }
        if let area = selectedArea {
            let (siteArea, _) = parseAreaCountry(site.location)
            if siteArea != area.name {
                return false
            }
        }
        return true
    }

    var visitedCount: Int {
        sites.filter { $0.visitedCount > 0 }.count
    }

    var wishlistCount: Int {
        sites.filter { $0.wishlist }.count
    }

    var plannedCount: Int {
        0  // TODO
    }

    var areasInSelectedRegion: [Area] {
        guard let region = selectedRegion else { return [] }
        let regionSites = sites.filter { $0.region == region.name }
        let groups = Dictionary(grouping: regionSites) { parseAreaCountry($0.location).area }
        let shopsInRegion = shops.filter { $0.region == region.name }
        return groups.map { entry in
            let areaName = entry.key
            let country = parseAreaCountry(entry.value.first!.location).country
            let shopCount = shopsInRegion.filter { ($0.area ?? "") == areaName }.count
            return Area(
                id: areaName,
                name: areaName,
                country: country,
                siteCount: entry.value.count,
                shopCount: shopCount
            )
        }
            .sorted { $0.name < $1.name }
    }

    private func saveFilterPreferences() {
        defaults.set(mode == .explore ? "explore" : "myMap", forKey: Self.modeKey)
        defaults.set(statusFilterString(statusFilter), forKey: Self.statusFilterKey)
        defaults.set(exploreFilterString(exploreFilter), forKey: Self.exploreFilterKey)
    }

    // MARK: - Map State Persistence (US-2)

    /// Save map state (center + zoom) to UserDefaults
    func saveMapState(center: CLLocationCoordinate2D, zoom: Double) {
        defaults.set(center.latitude, forKey: Self.lastCenterLatKey)
        defaults.set(center.longitude, forKey: Self.lastCenterLonKey)
        defaults.set(zoom, forKey: Self.lastZoomKey)
    }

    /// Load last saved map state, returns nil if no saved state exists
    func loadLastMapState() -> (center: CLLocationCoordinate2D, zoom: Double)? {
        guard defaults.object(forKey: Self.lastCenterLatKey) != nil else { return nil }
        let lat = defaults.double(forKey: Self.lastCenterLatKey)
        let lon = defaults.double(forKey: Self.lastCenterLonKey)
        let zoom = defaults.double(forKey: Self.lastZoomKey)
        // Validate reasonable values
        guard lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180 && zoom > 0 else { return nil }
        return (CLLocationCoordinate2D(latitude: lat, longitude: lon), zoom)
    }

    /// Clear saved map state (useful for testing or reset)
    func clearMapState() {
        defaults.removeObject(forKey: Self.lastCenterLatKey)
        defaults.removeObject(forKey: Self.lastCenterLonKey)
        defaults.removeObject(forKey: Self.lastZoomKey)
    }

    private func statusFilterString(_ filter: StatusFilter) -> String {
        switch filter {
        case .visited: return "visited"
        case .wishlist: return "wishlist"
        case .planned: return "planned"
        }
    }

    private func exploreFilterString(_ filter: ExploreFilter) -> String {
        switch filter {
        case .all: return "all"
        case .nearby: return "nearby"
        case .popular: return "popular"
        case .beginner: return "beginner"
        case .wrecks: return "wrecks"
        }
    }

    private static func parseStatusFilter(_ string: String) -> StatusFilter {
        switch string {
        case "visited": return .visited
        case "planned": return .planned
        default: return .wishlist
        }
    }

    private static func parseExploreFilter(_ string: String) -> ExploreFilter {
        switch string {
        case "nearby": return .nearby
        case "popular": return .popular
        case "beginner": return .beginner
        case "wrecks": return .wrecks
        default: return .all
        }
    }

    private func applyWishlistUpdate(_ notification: Notification) {
        guard let siteId = notification.object as? String else { return }
        let repository = SiteRepository(database: AppDatabase.shared)
        do {
            guard let updatedSite = try repository.fetch(id: siteId) else { return }
            if let index = sites.firstIndex(where: { $0.id == siteId }) {
                sites[index] = updatedSite
            }
            if let index = visibleSites.firstIndex(where: { $0.id == siteId }) {
                visibleSites[index] = updatedSite
            }
        } catch {
            print("❌ Failed to refresh wishlist state: \(error)")
        }
    }

    func loadSites() async {
        defer {
            DispatchQueue.main.async { [weak self] in
                self?.loading = false
            }
        }

        await MainActor.run {
            self.loading = true
        }

        let database = AppDatabase.shared
        let siteRepo = SiteRepository(database: database)
        let shopRepo = ShopRepository(database: database)
        do {
            do {
                try DatabaseSeeder.seedIfNeeded()
            } catch {
                print("Failed to seed database before loading sites: \(error)")
            }
            let fetchedSites = try siteRepo.fetchAll()
            let fetchedShops = try shopRepo.fetchAll()
            let regionNames = Set(fetchedSites.map { $0.region })
            let computedRegions = regionNames.map { name in
                let regionSites = fetchedSites.filter { $0.region == name }
                let regionShops = fetchedShops.filter { $0.region == name }
                return Region(
                    id: name,
                    name: name,
                    totalSites: regionSites.count,
                    visitedCount: regionSites.filter { $0.visitedCount > 0 }.count,
                    shopCount: regionShops.count
                )
            }.sorted { $0.name < $1.name }

            await MainActor.run {
                self.sites = fetchedSites
                self.shops = fetchedShops
                self.regions = computedRegions
                // Initialize visible sites to all sites
                self.visibleSites = fetchedSites
            }
        } catch {
            print("Failed to load sites: \(error)")
            await MainActor.run {
                self.sites = []
                self.shops = []
                self.regions = []
            }
        }
    }

    func resetToRegions() {
        selectedRegion = nil
        selectedArea = nil
        tier = .regions
    }

    func resetToAreas() {
        guard selectedRegion != nil else { return }
        selectedArea = nil
        tier = .areas
    }

    private var viewportDebounceTask: Task<Void, Never>?

    func scheduleRefreshVisibleSites(in region: MKCoordinateRegion) {
        scheduleRefreshVisibleSites(bounds: MapBounds(region: region))
    }

    func scheduleRefreshVisibleSites(bounds: MapBounds) {
        viewportDebounceTask?.cancel()
        viewportDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 150_000_000)
            await self?.refreshVisibleSites(bounds: bounds)
        }
    }

    func refreshVisibleSites(in region: MKCoordinateRegion) async {
        await refreshVisibleSites(bounds: MapBounds(region: region))
    }

    private func refreshVisibleSites(bounds: MapBounds) async {
        let repo = SiteRepository(database: AppDatabase.shared)
        do {
            let boxSites = try repo.fetchInBounds(
                minLat: bounds.minLatitude,
                maxLat: bounds.maxLatitude,
                minLon: bounds.minLongitude,
                maxLon: bounds.maxLongitude
            )
            let sitesToShow = boxSites.isEmpty ? self.sites : boxSites

            await MainActor.run {
                // Only update if the result is actually different to avoid unnecessary re-renders
                if sitesToShow.count != self.visibleSites.count || !sitesToShow.elementsEqual(self.visibleSites, by: { $0.id == $1.id }) {
                    self.visibleSites = sitesToShow
                }
            }
        } catch {
            print("Failed to fetch box sites: \(error)")
            // On error, show all sites
            await MainActor.run {
                if self.visibleSites.count != self.sites.count {
                    self.visibleSites = self.sites
                }
            }
        }
    }
}

// MARK: - Enums

enum MapMode {
    case myMap, explore
}

enum StatusFilter {
    case visited, wishlist, planned
}

enum ExploreFilter {
    case all, nearby, popular, beginner, wrecks
}

extension StatusFilter {
    var displayName: String {
        switch self {
        case .visited: return "Visited"
        case .wishlist: return "Wishlist"
        case .planned: return "Planned"
        }
    }
}

extension ExploreFilter {
    var displayName: String {
        switch self {
        case .all: return "All"
        case .nearby: return "Nearby"
        case .popular: return "Popular"
        case .beginner: return "Beginner"
        case .wrecks: return "Wrecks"
        }
    }
}

enum Tier {
    case regions, areas, sites
}

// MARK: - Models

struct Region: Identifiable, Equatable {
    let id: String
    let name: String
    let totalSites: Int
    let visitedCount: Int
    let shopCount: Int
}

struct Area: Identifiable, Equatable {
    let id: String
    let name: String
    let country: String
    let siteCount: Int
    let shopCount: Int
}

// MARK: - V3 Enums

enum Scope { case saved, discover }
enum EntityTab { case areas, sites }
enum MySitesTab { case timeline, saved, planned }

// MARK: - Helpers

/// Parse "Area, Country" from location string
func parseAreaCountry(_ location: String) -> (area: String, country: String) {
    let parts = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    if parts.count >= 2 { return (String(parts[0]), String(parts[1])) }
    return (location, "")
}
