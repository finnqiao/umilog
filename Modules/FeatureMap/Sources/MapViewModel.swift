import SwiftUI
import MapKit  // For MKCoordinateRegion/Span types
import CoreLocation  // For CLLocationCoordinate2D
import UmiDB
import DiveMap
import UmiCoreKit
import os

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

/// Manages map data including sites, shops, and regions.
/// UI state has been migrated to MapUIViewModel (Step 14).
/// Legacy filter properties retained for backward compatibility with filter sheets.
@MainActor
class MapViewModel: ObservableObject {
    // MARK: - Legacy State (Deprecated - use MapUIViewModel instead)
    // These properties are retained for backward compatibility with CombinedFilterLayersSheet.
    // New code should use MapUIViewModel.exploreFilters and MapUIViewModel.exploreContext.filterLens.

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

    // MARK: - Active State

    @Published var layerSettings: MapLayerSettings = MapLayerSettings()

    @Published var sites: [DiveSite] = []
    @Published var shops: [MapDiveShop] = []
    @Published var regions: [Region] = []
    @Published var loading: Bool = false
    @Published var visibleSites: [DiveSite] = []
    @Published private(set) var totalSiteCount: Int = 0
    @Published private(set) var isUsingSampledDataset: Bool = false

    private var wishlistObserver: NSObjectProtocol?
    private var safeModeObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private static let modeKey = "map.filter.mode"
    private static let statusFilterKey = "map.filter.status"
    private static let exploreFilterKey = "map.filter.explore"
    private var adaptiveViewportLimit: Int = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKeys.launchSafeModeEnabled)
        ? AppConstants.LaunchStability.viewportSiteQuerySafeModeLimit
        : AppConstants.LaunchStability.viewportSiteQueryLimit
    private var consecutiveSlowViewportQueries: Int = 0
    private var consecutiveViewportFailures: Int = 0
    private var fallbackSites: [DiveSite] = []
    private var hasRequestedFullDatasetWarmup = false

    // MARK: - Map State Persistence (US-2)
    private static let lastCenterLatKey = "map.lastCenter.lat"
    private static let lastCenterLonKey = "map.lastCenter.lon"
    private static let lastZoomKey = "map.lastZoom"

    private var isLaunchSafeModeEnabled: Bool {
        defaults.bool(forKey: AppConstants.UserDefaultsKeys.launchSafeModeEnabled)
    }

    private var initialSiteLoadLimit: Int {
        isLaunchSafeModeEnabled
            ? AppConstants.LaunchStability.initialSiteLoadSafeModeLimit
            : AppConstants.LaunchStability.initialSiteLoadLimit
    }

    private var viewportLimitBounds: (min: Int, max: Int) {
        let safeModeMax = AppConstants.LaunchStability.viewportSiteQuerySafeModeLimit
        if isLaunchSafeModeEnabled {
            return (min: max(200, safeModeMax / 2), max: safeModeMax)
        }
        let normalMax = AppConstants.LaunchStability.viewportSiteQueryLimit
        return (min: max(400, normalMax / 3), max: normalMax)
    }

    private var worldFallbackSampleLimit: Int {
        isLaunchSafeModeEnabled
            ? AppConstants.LaunchStability.allSitesExpansionSafeModeThreshold
            : AppConstants.LaunchStability.allSitesExpansionThreshold
    }

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
            Task { @MainActor in
                self?.applyWishlistUpdate(notification)
            }
        }

        safeModeObserver = NotificationCenter.default.addObserver(
            forName: .launchSafeModeDidChange,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let enabled = notification.userInfo?["enabled"] as? Bool else { return }
            Task { @MainActor in
                self?.handleSafeModeChanged(enabled)
            }
        }
    }

    deinit {
        if let wishlistObserver {
            NotificationCenter.default.removeObserver(wishlistObserver)
        }
        if let safeModeObserver {
            NotificationCenter.default.removeObserver(safeModeObserver)
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
                return site.isPlanned
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

    // MARK: - New Filter Methods (Step 14 migration)

    /// Apply filters using the new unified state types.
    /// - Parameters:
    ///   - sites: The source sites to filter
    ///   - filters: The ExploreFilters from MapUIViewModel
    ///   - lens: Optional FilterLens for "My Sites" mode
    ///   - hierarchy: The current hierarchy level
    /// - Returns: Filtered and sorted sites (by popularity: logged > wishlist > planned > alphabetical)
    func applyFilters(
        to sites: [DiveSite],
        filters: ExploreFilters,
        lens: FilterLens?,
        hierarchy: HierarchyLevel
    ) -> [DiveSite] {
        let filtered = sites.filter { site in
            // Apply hierarchy filter
            guard matchesHierarchy(site, level: hierarchy) else { return false }

            // Apply filter lens (My Sites mode) if active
            if let lens = lens {
                switch lens {
                case .saved:
                    guard site.wishlist else { return false }
                case .logged:
                    guard site.visitedCount > 0 else { return false }
                case .planned:
                    guard site.isPlanned else { return false }
                }
            }

            // Apply explore filters
            if !filters.difficulty.isEmpty {
                guard filters.difficulty.contains(site.difficulty) else { return false }
            }

            if !filters.siteType.isEmpty {
                guard filters.siteType.contains(site.type) else { return false }
            }

            if let depthRange = filters.maxDepthRange {
                guard depthRange.contains(site.maxDepth) else { return false }
            }

            return true
        }

        // Sort by popularity: logged sites first, then wishlist, then planned, then alphabetically
        return filtered.sorted { a, b in
            // Priority: visited > wishlist > planned > others
            let aPriority = sitePopularityScore(a)
            let bPriority = sitePopularityScore(b)
            if aPriority != bPriority {
                return aPriority > bPriority
            }
            // Same priority - sort alphabetically
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    /// Calculate a popularity score for sorting (higher = more popular/engaged).
    private func sitePopularityScore(_ site: DiveSite) -> Int {
        var score = 0
        if site.visitedCount > 0 { score += 100 + site.visitedCount }
        if site.wishlist { score += 50 }
        if site.isPlanned { score += 25 }
        return score
    }

    /// Check if a site matches the given hierarchy level.
    private func matchesHierarchy(_ site: DiveSite, level: HierarchyLevel) -> Bool {
        switch level {
        case .world:
            return true
        case .country(let countryId):
            return site.countryId == countryId
        case .region(_, let regionId):
            return site.regionId == regionId || site.region == regionId
        case .area(let regionId, let areaId):
            guard site.regionId == regionId || site.region == regionId else { return false }
            let (siteArea, _) = parseAreaCountry(site.location)
            return siteArea == areaId || site.areaId == areaId
        }
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
            Log.map.error("Failed to refresh wishlist state: \(error.localizedDescription)")
        }
    }

    private struct SiteBootPayload {
        let sites: [DiveSite]
        let shops: [MapDiveShop]
        let regions: [Region]
        let totalSiteCount: Int
        let fallbackSites: [DiveSite]
        let isSampled: Bool
    }

    func loadSites() async {
        defer { loading = false }
        loading = true

        let launchSafeMode = isLaunchSafeModeEnabled
        let bootstrapLimit = initialSiteLoadLimit
        let fallbackSampleLimit = worldFallbackSampleLimit
        let viewportBounds = viewportLimitBounds
        adaptiveViewportLimit = viewportBounds.max
        let startedAt = Date()

        let loadResult = await Task.detached(priority: .userInitiated) {
            Result<SiteBootPayload, Error> {
                try DatabaseSeeder.seedCriticalDataIfNeeded()

                let database = AppDatabase.shared
                let siteRepo = SiteRepository(database: database)
                let shopRepo = ShopRepository(database: database)

                let fetchedSites = try siteRepo.fetchRanked(limit: bootstrapLimit)
                let totalSiteCount = try siteRepo.countSites()
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

                let fallbackSites = Array(fetchedSites.prefix(fallbackSampleLimit))
                let isSampled = totalSiteCount > fetchedSites.count

                return SiteBootPayload(
                    sites: fetchedSites,
                    shops: fetchedShops,
                    regions: computedRegions,
                    totalSiteCount: totalSiteCount,
                    fallbackSites: fallbackSites,
                    isSampled: isSampled
                )
            }
        }.value

        switch loadResult {
        case .success(let payload):
            sites = payload.sites
            shops = payload.shops
            regions = payload.regions
            visibleSites = payload.sites
            totalSiteCount = payload.totalSiteCount
            isUsingSampledDataset = payload.isSampled
            fallbackSites = payload.fallbackSites

            let elapsed = Date().timeIntervalSince(startedAt)
            Log.map.info(
                "Map bootstrap loaded \(payload.sites.count, privacy: .public)/\(payload.totalSiteCount, privacy: .public) sites in \(elapsed, privacy: .public)s (safeMode=\(launchSafeMode, privacy: .public))"
            )

            if payload.isSampled && !launchSafeMode {
                startFullDatasetWarmupIfNeeded()
            }
        case .failure(let error):
            Log.map.error("Failed to load sites: \(error.localizedDescription)")
            sites = []
            shops = []
            regions = []
            visibleSites = []
            totalSiteCount = 0
            isUsingSampledDataset = false
            fallbackSites = []
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
        let queryStartedAt = Date()
        let currentLimit = adaptiveViewportLimit
        let minLat = bounds.minLatitude
        let maxLat = bounds.maxLatitude
        let minLon = bounds.minLongitude
        let maxLon = bounds.maxLongitude
        let queryResult = await Task.detached(priority: .utility) {
            Result<[DiveSite], Error> {
                try SiteRepository(database: AppDatabase.shared).fetchInBounds(
                    minLat: minLat,
                    maxLat: maxLat,
                    minLon: minLon,
                    maxLon: maxLon,
                    limit: currentLimit
                )
            }
        }.value
        switch queryResult {
        case .success(let boxSites):
            let sitesToShow = boxSites.isEmpty ? fallbackSites : boxSites

            // Only update if the result is actually different to avoid unnecessary re-renders
            if sitesToShow.count != self.visibleSites.count || !sitesToShow.elementsEqual(self.visibleSites, by: { $0.id == $1.id }) {
                self.visibleSites = sitesToShow
            }

            recordViewportQuery(duration: Date().timeIntervalSince(queryStartedAt), fetchedCount: boxSites.count)

            // Prefetch images for visible sites (fire-and-forget)
            await prefetchImagesForSites(sitesToShow)
        case .failure(let error):
            Log.map.debug("Failed to fetch box sites: \(error.localizedDescription)")
            consecutiveViewportFailures += 1
            if consecutiveViewportFailures >= AppConstants.LaunchStability.viewportFailureEscalationThreshold {
                NotificationCenter.default.post(
                    name: .launchSafeModeActivationRequested,
                    object: nil,
                    userInfo: ["reason": "viewport_query_failures"]
                )
            }

            // On error, keep fallback sample instead of loading all sites.
            if !self.fallbackSites.isEmpty && self.visibleSites.count != self.fallbackSites.count {
                self.visibleSites = self.fallbackSites
            }
        }
    }

    private func handleSafeModeChanged(_ enabled: Bool) {
        let bounds = viewportLimitBounds
        adaptiveViewportLimit = min(max(adaptiveViewportLimit, bounds.min), bounds.max)
        consecutiveSlowViewportQueries = 0
        consecutiveViewportFailures = 0

        if enabled {
            let cappedFallback = Array(sites.prefix(worldFallbackSampleLimit))
            fallbackSites = cappedFallback
            if visibleSites.count > adaptiveViewportLimit {
                visibleSites = Array(visibleSites.prefix(adaptiveViewportLimit))
            }
        } else if isUsingSampledDataset {
            startFullDatasetWarmupIfNeeded()
        }
    }

    private func startFullDatasetWarmupIfNeeded() {
        guard !hasRequestedFullDatasetWarmup, !isLaunchSafeModeEnabled else { return }
        hasRequestedFullDatasetWarmup = true

        Task { [weak self] in
            let startedAt = Date()
            let warmupResult = await Task.detached(priority: .utility) {
                Result<[DiveSite], Error> {
                    try SiteRepository(database: AppDatabase.shared).fetchAll()
                }
            }.value

            guard let self else { return }

            switch warmupResult {
            case .success(let fullSites):
                await MainActor.run {
                    self.sites = fullSites
                    self.totalSiteCount = fullSites.count
                    self.isUsingSampledDataset = false
                    self.fallbackSites = Array(fullSites.prefix(self.worldFallbackSampleLimit))
                    let elapsed = Date().timeIntervalSince(startedAt)
                    Log.map.info("Map full dataset warmup complete: \(fullSites.count, privacy: .public) sites in \(elapsed, privacy: .public)s")
                }
            case .failure(let error):
                await MainActor.run {
                    self.hasRequestedFullDatasetWarmup = false
                    Log.map.error("Map full dataset warmup failed: \(error.localizedDescription)")
                }
            }
        }
    }

    private func recordViewportQuery(duration: TimeInterval, fetchedCount: Int) {
        self.consecutiveViewportFailures = 0
        let bounds = self.viewportLimitBounds
        self.adaptiveViewportLimit = min(max(self.adaptiveViewportLimit, bounds.min), bounds.max)

        if duration > AppConstants.LaunchStability.slowViewportQueryThreshold {
            self.consecutiveSlowViewportQueries += 1
            let reduced = max(bounds.min, Int(Double(self.adaptiveViewportLimit) * 0.75))
            if reduced < self.adaptiveViewportLimit {
                self.adaptiveViewportLimit = reduced
                Log.map.info("Viewport query slow (\(duration, privacy: .public)s); reducing limit to \(self.adaptiveViewportLimit, privacy: .public)")
            }

            if self.consecutiveSlowViewportQueries >= AppConstants.LaunchStability.viewportSlowQueryEscalationThreshold {
                NotificationCenter.default.post(
                    name: .launchSafeModeActivationRequested,
                    object: nil,
                    userInfo: ["reason": "viewport_query_slow"]
                )
            }
            return
        }

        self.consecutiveSlowViewportQueries = 0
        if fetchedCount >= Int(Double(self.adaptiveViewportLimit) * 0.9), self.adaptiveViewportLimit < bounds.max {
            self.adaptiveViewportLimit = min(bounds.max, self.adaptiveViewportLimit + 300)
        }
    }

    /// Prefetch images for visible sites in the viewport.
    private func prefetchImagesForSites(_ sites: [DiveSite]) async {
        guard !sites.isEmpty else { return }

        let siteIds = sites.prefix(50).map(\.id)  // Limit to 50 sites
        let mediaRepo = SiteMediaRepository(database: AppDatabase.shared)

        do {
            let mediaMap = try mediaRepo.fetchMediaBatch(siteIds: Array(siteIds))
            var urlMap: [String: URL] = [:]
            for (siteId, media) in mediaMap {
                if let url = URL(string: media.url) {
                    urlMap[siteId] = url
                }
            }

            // Fire-and-forget prefetch via ImageCacheService
            await ImageCacheService.shared.prefetch(siteIds: Array(siteIds), urls: urlMap)
        } catch {
            Log.images.debug("Failed to fetch media for prefetch: \(error.localizedDescription)")
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
