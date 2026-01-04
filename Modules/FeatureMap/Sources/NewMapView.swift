import SwiftUI
import MapKit
import UmiDB
import FeatureLiveLog
import UmiDesignSystem
import DiveMap
import UmiCoreKit
import UmiLocationKit
import UIKit

// MARK: - Native MapKit View (iOS 18 compatible)

struct NativeMapView: UIViewRepresentable {
    let sites: [DiveSite]
    @Binding var region: MKCoordinateRegion
    var onSelect: (String) -> Void
    var onRegionChange: (MKCoordinateRegion) -> Void

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.setRegion(region, animated: false)

        // Dark ocean style
        mapView.overrideUserInterfaceStyle = .dark

        // Register custom annotation view
        mapView.register(SiteAnnotationView.self, forAnnotationViewWithReuseIdentifier: SiteAnnotationView.reuseIdentifier)
        mapView.register(ClusterAnnotationView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update annotations only - don't touch the region to avoid feedback loops
        // The map controls its own camera; we just read the region via onRegionChange
        let existingIds = Set(mapView.annotations.compactMap { ($0 as? SiteAnnotation)?.siteId })
        let newIds = Set(sites.map { $0.id })

        // Remove old
        let toRemove = mapView.annotations.filter {
            guard let site = $0 as? SiteAnnotation else { return false }
            return !newIds.contains(site.siteId)
        }
        mapView.removeAnnotations(toRemove)

        // Add new
        let toAdd = sites.filter { !existingIds.contains($0.id) }
        let newAnnotations = toAdd.map { SiteAnnotation(site: $0) }
        mapView.addAnnotations(newAnnotations)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: NativeMapView

        init(_ parent: NativeMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let cluster = annotation as? MKClusterAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: annotation) as? ClusterAnnotationView
                    ?? ClusterAnnotationView(annotation: cluster, reuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
                view.annotation = cluster
                return view
            }

            guard let siteAnnotation = annotation as? SiteAnnotation else { return nil }

            let view = mapView.dequeueReusableAnnotationView(withIdentifier: SiteAnnotationView.reuseIdentifier, for: annotation) as? SiteAnnotationView
                ?? SiteAnnotationView(annotation: siteAnnotation, reuseIdentifier: SiteAnnotationView.reuseIdentifier)
            view.annotation = siteAnnotation
            view.clusteringIdentifier = "site"
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: MKAnnotation) {
            if let cluster = annotation as? MKClusterAnnotation {
                // Zoom into cluster - calculate bounding rect of member annotations
                var minLat = Double.greatestFiniteMagnitude
                var maxLat = -Double.greatestFiniteMagnitude
                var minLon = Double.greatestFiniteMagnitude
                var maxLon = -Double.greatestFiniteMagnitude

                for member in cluster.memberAnnotations {
                    minLat = min(minLat, member.coordinate.latitude)
                    maxLat = max(maxLat, member.coordinate.latitude)
                    minLon = min(minLon, member.coordinate.longitude)
                    maxLon = max(maxLon, member.coordinate.longitude)
                }

                // Add padding and ensure minimum zoom
                let latPadding = max((maxLat - minLat) * 0.3, 0.01)
                let lonPadding = max((maxLon - minLon) * 0.3, 0.01)

                let region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(
                        latitude: (minLat + maxLat) / 2,
                        longitude: (minLon + maxLon) / 2
                    ),
                    span: MKCoordinateSpan(
                        latitudeDelta: (maxLat - minLat) + latPadding,
                        longitudeDelta: (maxLon - minLon) + lonPadding
                    )
                )

                mapView.deselectAnnotation(annotation, animated: false)
                mapView.setRegion(region, animated: true)
                return
            }

            guard let siteAnnotation = annotation as? SiteAnnotation else { return }
            mapView.deselectAnnotation(annotation, animated: false)
            parent.onSelect(siteAnnotation.siteId)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChange(mapView.region)
        }
    }
}

// MARK: - Site Annotation

class SiteAnnotation: NSObject, MKAnnotation {
    let siteId: String
    let siteName: String
    let coordinate: CLLocationCoordinate2D

    init(site: DiveSite) {
        self.siteId = site.id
        self.siteName = site.name
        self.coordinate = CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude)
    }

    var title: String? { siteName }
}

// MARK: - Site Annotation View (Tan/Cream Pin)

class SiteAnnotationView: MKAnnotationView {
    static let reuseIdentifier = "SiteAnnotation"

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        clusteringIdentifier = "site"
        collisionMode = .circle
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    private func setupView() {
        // Enable selection (GAP-011 fix)
        canShowCallout = false  // We handle selection via delegate
        isEnabled = true  // Make tappable

        // Tan/cream colored pin like reference images
        let size: CGFloat = 24
        let pinView = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        pinView.backgroundColor = UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1.0) // Tan/cream
        pinView.layer.cornerRadius = size / 2
        pinView.layer.borderWidth = 2
        pinView.layer.borderColor = UIColor.white.cgColor
        pinView.layer.shadowColor = UIColor.black.cgColor
        pinView.layer.shadowOffset = CGSize(width: 0, height: 2)
        pinView.layer.shadowRadius = 4
        pinView.layer.shadowOpacity = 0.3

        // Ensure tap target is at least 44x44 (Apple HIG)
        let tapSize: CGFloat = 44
        frame = CGRect(x: 0, y: 0, width: tapSize, height: tapSize)
        centerOffset = CGPoint(x: 0, y: -tapSize / 2)

        pinView.center = CGPoint(x: tapSize / 2, y: tapSize / 2)
        addSubview(pinView)

        // Accessibility
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        if let siteAnnotation = annotation as? SiteAnnotation {
            accessibilityLabel = "Dive site: \(siteAnnotation.siteName)"
            accessibilityHint = "Double tap to view site details"
        }
    }
}

// MARK: - Cluster Annotation View (Tan circle with count)

class ClusterAnnotationView: MKAnnotationView {
    private let countLabel = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        setupView()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    override var annotation: MKAnnotation? {
        didSet {
            guard let cluster = annotation as? MKClusterAnnotation else { return }
            countLabel.text = "\(cluster.memberAnnotations.count)"

            // Adjust size based on count
            let count = cluster.memberAnnotations.count
            let size: CGFloat = count > 100 ? 56 : count > 50 ? 48 : count > 10 ? 40 : 32
            frame.size = CGSize(width: size, height: size)
            layer.cornerRadius = size / 2
            countLabel.frame = bounds
        }
    }

    private func setupView() {
        // Enable selection (GAP-011 fix)
        canShowCallout = false  // We handle selection via delegate
        isEnabled = true  // Make tappable

        // Tan/cream background like reference
        backgroundColor = UIColor(red: 0.96, green: 0.87, blue: 0.70, alpha: 1.0)
        layer.borderWidth = 2.5
        layer.borderColor = UIColor.white.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        layer.shadowOpacity = 0.3

        // Count label
        countLabel.textAlignment = .center
        countLabel.textColor = UIColor(red: 0.2, green: 0.15, blue: 0.1, alpha: 1.0) // Dark brown
        countLabel.font = UIFont.boldSystemFont(ofSize: 14)
        addSubview(countLabel)

        // Accessibility
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    override func prepareForDisplay() {
        super.prepareForDisplay()
        if let cluster = annotation as? MKClusterAnnotation {
            let count = cluster.memberAnnotations.count
            accessibilityLabel = "\(count) dive sites grouped"
            accessibilityHint = "Double tap to zoom in"
        }
    }
}

struct MapLayerSettings: Equatable {
    var showUnderwaterGlow: Bool = true
    var showClusters: Bool = true
    var showStatusGlows: Bool = true
    var colorByDifficulty: Bool = true
}

public struct MapAppearance {
    public var backgroundTop: Color
    public var backgroundBottom: Color

    public static let `default` = MapAppearance(
        backgroundTop: Color(red: 0.06, green: 0.14, blue: 0.24),
        backgroundBottom: Color(red: 0.04, green: 0.11, blue: 0.19)
    )

    public init(backgroundTop: Color, backgroundBottom: Color) {
        self.backgroundTop = backgroundTop
        self.backgroundBottom = backgroundBottom
    }
}

public struct NewMapView: View {
    private let appearance: MapAppearance
    @StateObject private var viewModel = MapViewModel()
    @StateObject private var uiViewModel = MapUIViewModel()
    @StateObject private var featuredService = FeaturedDestinationService.shared
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private let tabBarHeight: CGFloat = 72
    // Start with world view to avoid flashing a hardcoded location
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 180, longitudeDelta: 360)
    )
    @State private var isMapInitialized = false
    @State private var selectedSite: DiveSite?

    // Unified surface state
    @State private var surfaceDetent: SurfaceDetent = .peek
    @State private var isProgrammaticCameraChange = false
    @State private var showFeaturedCard = false

    // Site callout state
    @State private var showCallout = false
    @State private var calloutSite: DiveSite?
    @State private var calloutMediaURL: URL?
#if DEBUG
    @State private var showDebugHUD = false
#endif

    // Selection and syncing
    @State private var selectedSiteIdForScroll: String?
    @State private var followMap: Bool = true

    // Track camera fits for recenter
    @State private var lastFittedRegion: MKCoordinateRegion?
    @State private var lastViewport: DiveMapViewport?

    // Location (for contextual FAB)
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var geofenceManager = GeofenceManager.shared

    // Repositories for bounds lookups and queries
    private let geographyRepository = GeographyRepository(database: AppDatabase.shared)
    private let siteRepository = SiteRepository(database: AppDatabase.shared)

    // V3 scope and entity tabs
    @State private var scope: Scope = .discover
    @State private var entityTab: EntityTab = .sites
    @State private var mySitesTab: MySitesTab = .saved

    // Coming Soon toast state
    @State private var showingComingSoonToast = false
    @State private var comingSoonFeature = ""
    
    public init(appearance: MapAppearance = .default) {
        self.appearance = appearance
    }
    
    private var primaryColor: Color { scope == .discover ? .reef : .lagoon }

    private var baseSitesForCounts: [DiveSite] {
        let viewportSites = viewModel.visibleSites.isEmpty ? viewModel.sites : viewModel.visibleSites
        if scope == .discover {
            return viewModel.applyExploreFilters(to: viewportSites)
        } else {
            return viewModel.applyMyMapFilters(to: viewportSites)
        }
    }

    /// Sites filtered using the new unified state types from MapUIViewModel.
    /// Used by UnifiedBottomSurface and will eventually replace baseSitesForCounts.
    private var unifiedFilteredSites: [DiveSite] {
        let viewportSites = viewModel.visibleSites.isEmpty ? viewModel.sites : viewModel.visibleSites
        return viewModel.applyFilters(
            to: viewportSites,
            filters: uiViewModel.exploreFilters,
            lens: uiViewModel.exploreContext?.filterLens,
            hierarchy: uiViewModel.currentHierarchyLevel
        )
    }

    // MARK: - Hierarchy Helpers (Step 14.2)

    /// Current hierarchy level from the unified UI state.
    private var currentHierarchy: HierarchyLevel {
        uiViewModel.currentHierarchyLevel
    }

    /// Whether we're drilled into a region or area (not at world level).
    private var isDrilledDown: Bool {
        !currentHierarchy.isWorld
    }

    /// The current region ID if drilled into a region or area, nil at world level.
    private var currentRegionId: String? {
        currentHierarchy.regionId
    }

    /// The current area ID if drilled into an area, nil otherwise.
    private var currentAreaId: String? {
        currentHierarchy.areaId
    }

    /// The Region model for the current hierarchy level, if applicable.
    private var currentRegion: Region? {
        guard let regionId = currentRegionId else { return nil }
        return viewModel.regions.first { $0.id == regionId }
    }

    /// The current tier based on hierarchy level (for backward compat with tier-based views).
    private var currentTier: Tier {
        switch currentHierarchy {
        case .world:
            return .regions
        case .country:
            return .regions  // At country level, show regions within that country
        case .region:
            return .areas
        case .area:
            return .sites
        }
    }

    /// Areas in the currently selected region, using new hierarchy.
    private var areasInCurrentRegion: [Area] {
        guard let regionId = currentRegionId else { return [] }
        let regionSites = viewModel.sites.filter { $0.region == regionId }
        let groups = Dictionary(grouping: regionSites) { parseAreaCountry($0.location).area }
        let shopsInRegion = viewModel.shops.filter { $0.region == regionId }
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
        }.sorted { $0.name < $1.name }
    }

    private var areasInViewCount: Int {
        let names = baseSitesForCounts.map { parseAreaCountry($0.location).area }
        return Set(names).count
    }

    private var discoverCountLabel: String {
        switch entityTab {
        case .areas:
            return "Areas in view: \(abbreviatedCount(areasInViewCount))"
        case .sites:
            return "Sites in view: \(abbreviatedCount(baseSitesForCounts.count))"
        }
    }

    private var mySitesCountLabel: String {
        switch mySitesTab {
        case .timeline:
            return "Sites in view: \(abbreviatedCount(baseSitesForCounts.count))"
        case .saved:
            return "Saved in view: \(abbreviatedCount(baseSitesForCounts.count))"
        case .planned:
            return "Planned in view: \(abbreviatedCount(baseSitesForCounts.count))"
        }
    }

    private var currentCountLabel: String {
        scope == .discover ? discoverCountLabel : mySitesCountLabel
    }

    private var shouldShowBreadcrumb: Bool {
        isDrilledDown
    }

    private var discoverSitesEmptyState: EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "mappin.slash",
            title: "No sites match your filters",
            message: "Try clearing filters or zooming out to broaden the search area.",
            primaryTitle: "Clear filters",
            primaryAction: {
                Haptics.tap()
                clearDiscoverFilters()
            },
            secondaryTitle: "Zoom out",
            secondaryAction: {
                Haptics.soft()
                fitToVisible()
            }
        )
    }

    private var mySitesEmptyState: EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "bookmark.slash",
            title: "You have no sites here",
            message: "Save sites or adjust filters to populate this list.",
            primaryTitle: "Reset My Sites",
            primaryAction: {
                Haptics.tap()
                clearMySitesFilters()
            },
            secondaryTitle: "Zoom out",
            secondaryAction: {
                Haptics.soft()
                fitToVisible()
            }
        )
    }

    private var discoverShopsEmptyState: EmptyStateConfiguration {
        EmptyStateConfiguration(
            icon: "building.2",
            title: "No shops nearby",
            message: "Adjust the map or filters to find dive shops in this region.",
            primaryTitle: "Reset filters",
            primaryAction: {
                Haptics.tap()
                clearDiscoverFilters()
            },
            secondaryTitle: "Zoom out",
            secondaryAction: {
                Haptics.soft()
                fitToVisible()
            }
        )
    }
    
    private var filtersScopeLabel: String {
        if scope == .discover {
            switch entityTab {
            case .areas: return "Filters · Areas"
            case .sites: return "Filters · Sites"
            }
        }
        return "Filters · My Sites"
    }

    private var filterSummaryText: String? {
        if scope == .discover {
            var parts: [String] = []
            // Use new unified filter state
            if uiViewModel.exploreFilters.isActive {
                parts.append("\(uiViewModel.exploreFilters.activeCount) filters")
            }
            if uiViewModel.exploreFilters.showShops {
                parts.append("Shops")
            }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } else {
            switch mySitesTab {
            case .timeline:
                return nil
            case .saved:
                return FilterLens.saved.displayName
            case .planned:
                return FilterLens.planned.displayName
            }
        }
    }

    private func fitToVisible() {
        followMap = true
        if scope == .discover && entityTab == .sites && uiViewModel.exploreFilters.showShops {
            focusMap(onShops: discoverShopsList, including: baseSitesForCounts)
            return
        }
        focusMap(on: baseSitesForCounts)
    }

    private var activeFilterCount: Int {
        uiViewModel.exploreFilters.activeCount
    }

    // Use the correct list for annotations to avoid accidental filtering to wishlist-only
    private var annotationSites: [DiveSite] {
        if scope == .discover {
            if entityTab == .sites || currentAreaId != nil {
                return discoverSitesList
            } else {
                return []
            }
        } else {
            return savedSitesList
        }
    }

    private var mapLibreAnnotations: [DiveMapAnnotation] {
        let latSpan: Double = {
            if let v = lastViewport { return v.maxLatitude - v.minLatitude }
            return mapRegion.span.latitudeDelta
        }()

        var annotations: [DiveMapAnnotation]

        if scope == .discover {
            switch entityTab {
            case .areas:
                annotations = areaAggregateAnnotations
            case .sites:
                annotations = siteAnnotations
            }
        } else {
            if latSpan > 60 {
                annotations = regionAggregateAnnotations
            } else if latSpan > 20 {
                annotations = areaAggregateAnnotations
            } else {
                annotations = siteAnnotations
            }
        }

        if scope == .discover && entityTab == .sites && uiViewModel.exploreFilters.showShops {
            annotations += shopAnnotations
        }

        return annotations
    }

#if DEBUG
    private var surfaceDetentLabel: String {
        switch surfaceDetent {
        case .peek: return "peek"
        case .medium: return "medium"
        case .expanded: return "expanded"
        }
    }

    private var datasetLabel: String {
        if scope == .discover {
            switch entityTab {
            case .areas: return "Discover · Areas"
            case .sites: return "Discover · Sites"
            }
        } else {
            switch mySitesTab {
            case .timeline: return "My Sites · Timeline"
            case .saved: return "My Sites · Saved"
            case .planned: return "My Sites · Planned"
            }
        }
    }

    private var visibleFeatureCount: Int {
        mapLibreAnnotations.count
    }

    private var debugHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Surface: \(surfaceDetentLabel)")
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
            Text(datasetLabel)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            Text("Filters: \(activeFilterCount) • Features: \(visibleFeatureCount)")
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
            HStack(spacing: 8) {
                Button("Fit all") { fitAllSites() }
                if currentAreaId != nil {
                    Button("Fit area") { fitSelectedArea() }
                }
                Button("Reset world") { resetCameraToWorld() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
        }
        .padding(12)
        .background(Color.black.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
#endif

    private var siteAnnotations: [DiveMapAnnotation] {
        let selectedId = selectedSite?.id
        // If visible set is tiny at world scale, fall back to all sites so clusters are visible
        let base = (scope == .discover && followMap && annotationSites.count < 100) ? viewModel.sites : annotationSites
        return base.map { site in
            let kind: DiveMapAnnotation.Kind = site.type == .wreck ? .wreck : .site
            let status: DiveMapAnnotation.Status = site.visitedCount > 0 ? .logged : (site.wishlist ? .saved : .baseline)
            let difficulty = DiveMapAnnotation.Difficulty(rawValue: site.difficulty.rawValue) ?? .other
            let siteType = DiveMapAnnotation.SiteType(rawValue: site.type.rawValue.lowercased()) ?? .generic
            return DiveMapAnnotation(
                id: site.id,
                coordinate: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude),
                kind: kind,
                status: status,
                difficulty: difficulty,
                siteType: siteType,
                visited: site.visitedCount > 0,
                wishlist: site.wishlist,
                isSelected: selectedId == site.id
            )
        }
    }
    
    private var shopAnnotations: [DiveMapAnnotation] {
        discoverShopsList.compactMap { shop in
            guard let latitude = shop.latitude, let longitude = shop.longitude else { return nil }
            return DiveMapAnnotation(
                id: "shop:\(shop.id)",
                coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                kind: .site,
                status: .saved,
                difficulty: .other,
                visited: false,
                wishlist: false,
                isSelected: false
            )
        }
    }

    private var regionAggregateAnnotations: [DiveMapAnnotation] {
        // One point per region (centroid)
        let sourceSites = scope == .discover ? discoverSitesList : savedSitesList
        let groups = Dictionary(grouping: sourceSites, by: { $0.region })
        return groups.map { (region, sites) in
            let lat = sites.map { $0.latitude }.average
            let lon = sites.map { $0.longitude }.average
            return DiveMapAnnotation(
                id: "region:\(region)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                kind: .site,
                status: .baseline,
                difficulty: .other,
                visited: false,
                wishlist: false,
                isSelected: false
            )
        }
    }

    private var areaAggregateAnnotations: [DiveMapAnnotation] {
        // One point per area (centroid). If a region is selected, limit to it.
        let baseSites: [DiveSite] = scope == .discover ? discoverSitesList : savedSitesList
        let filteredSites: [DiveSite] = {
            if let regionId = currentRegionId {
                return baseSites.filter { $0.region == regionId }
            }
            return baseSites
        }()
        let groups = Dictionary(grouping: filteredSites, by: { parseAreaCountry($0.location).area })
        return groups.map { (area, sites) in
            let lat = sites.map { $0.latitude }.average
            let lon = sites.map { $0.longitude }.average
            return DiveMapAnnotation(
                id: "area:\(area)",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                kind: .site,
                status: .baseline,
                difficulty: .other,
                visited: false,
                wishlist: false,
                isSelected: false
            )
        }
    }

    private func focusMap(on sites: [DiveSite], singleSpan: Double = 4.0) {
        let coordinates = sites.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        focusMap(onCoordinates: coordinates, singleSpan: singleSpan)
    }
    
    private func focusMap(onShops shops: [MapDiveShop], including sites: [DiveSite] = [], singleSpan: Double = 4.0) {
        var coordinates = shops.compactMap { shop -> CLLocationCoordinate2D? in
            guard let lat = shop.latitude, let lon = shop.longitude else { return nil }
            return CLLocationCoordinate2D(latitude: lat, longitude: lon)
        }
        coordinates.append(contentsOf: sites.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        })
        focusMap(onCoordinates: coordinates, singleSpan: singleSpan)
    }

    private func focusMap(onCoordinates coordinates: [CLLocationCoordinate2D], singleSpan: Double = 4.0) {
        guard !coordinates.isEmpty else { return }
        beginProgrammaticCameraChange()
        if coordinates.count == 1, let coordinate = coordinates.first {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: singleSpan, longitudeDelta: singleSpan)
            )
            lastFittedRegion = mapRegion
            return
        }

        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )

        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon
        let padding = 0.15  // 15% padding on each side
        let latSpan = max(latRange * (1.0 + padding * 2), 0.5)
        let lonSpan = max(lonRange * (1.0 + padding * 2), 0.75)

        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        lastFittedRegion = mapRegion
    }

    /// Focus map on geographic bounds with padding
    private func focusMap(onBounds bounds: GeographyRepository.Bounds) {
        beginProgrammaticCameraChange()
        let center = CLLocationCoordinate2D(
            latitude: bounds.centerLat,
            longitude: bounds.centerLon
        )
        let padding = 0.15  // 15% padding on each side
        let latSpan = max(bounds.latSpan * (1.0 + padding * 2), 0.5)
        let lonSpan = max(bounds.lonSpan * (1.0 + padding * 2), 0.75)

        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
        lastFittedRegion = mapRegion
    }

#if DEBUG
    private func fitAllSites() {
        focusMap(on: viewModel.sites)
    }

    private func fitSelectedArea() {
        guard let areaId = currentAreaId else { return }
        let areaSites = viewModel.sites.filter { parseAreaCountry($0.location).area == areaId }
        focusMap(on: areaSites.isEmpty ? viewModel.sites : areaSites)
    }

    private func resetCameraToWorld() {
        beginProgrammaticCameraChange()
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
        )
        followMap = true
        surfaceDetent = .peek
        lastFittedRegion = mapRegion
    }
#endif

    private func beginProgrammaticCameraChange() {
        isProgrammaticCameraChange = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProgrammaticCameraChange = false
        }
    }

    private var diveMapCamera: DiveMapCamera {
        let span = mapRegion.span
        let normalizedLatitude = max(span.latitudeDelta, 0.0001)
        let denominator = 30.0
        let baseZoom = 8.0 - log2(normalizedLatitude / denominator)
        let approxZoom = max(1.5, min(14.0, baseZoom))
        return DiveMapCamera(center: mapRegion.center, zoomLevel: approxZoom)
    }
    
    private var isOffCenter: Bool {
        guard let lastFittedRegion, let lastViewport else { return false }
        let fittedCenter = lastFittedRegion.center
        let currentCenter = CLLocationCoordinate2D(
            latitude: (lastViewport.minLatitude + lastViewport.maxLatitude) / 2.0,
            longitude: (lastViewport.minLongitude + lastViewport.maxLongitude) / 2.0
        )
        let dLat = abs(fittedCenter.latitude - currentCenter.latitude)
        let dLon = abs(fittedCenter.longitude - currentCenter.longitude)
        // Consider off-center if drift > 10% of fitted span
        let latThreshold = max(0.5, lastFittedRegion.span.latitudeDelta * 0.1)
        let lonThreshold = max(0.5, lastFittedRegion.span.longitudeDelta * 0.1)
        return dLat > latThreshold || dLon > lonThreshold
    }

    public var body: some View {
        mapView
            .tint(primaryColor)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: uiViewModel.currentHierarchyLevel) { _ in
                // Refocus map when hierarchy changes
                focusMap(on: unifiedFilteredSites)
            }
            .onChange(of: uiViewModel.exploreFilters) { _ in
                // Refocus map when filters change
                focusMap(on: unifiedFilteredSites)
            }
            .onChange(of: selectedSite) { _ in
                if let selectedSite { focusMap(on: [selectedSite]) }
            }
            .onChange(of: scope) { newScope in
                // Sync scope to filter lens
                if newScope == .discover {
                    uiViewModel.send(.clearFilterLens)
                    entityTab = .sites
                } else {
                    uiViewModel.exploreFilters.showShops = false
                    syncFilterLensToMySitesTab(mySitesTab)
                }
            }
            .onChange(of: mySitesTab) { newValue in
                syncFilterLensToMySitesTab(newValue)
            }
            .onChange(of: surfaceDetent) { newDetent in
                updateTabBarVisibility(for: newDetent)
            }
            .onChange(of: uiViewModel.mode) { newMode in
                // Dismiss callout when entering inspect mode (mutual exclusivity)
                if newMode.isInspecting && showCallout {
                    showCallout = false
                    calloutSite = nil
                }
            }
            .task {
                // Load sites and center map - called once on appear
                await viewModel.loadSites()

                // Small delay to ensure view is laid out
                try? await Task.sleep(nanoseconds: 50_000_000)

                // US-1: Smart initial positioning
                let sitesToCenter = await MainActor.run { viewModel.sites }
                if !sitesToCenter.isEmpty {
                    // Check for featured destination (first-time user)
                    if let featured = featuredService.checkAndSelectFeatured() {
                        // Animate to featured destination with fly-in effect
                        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms delay

                        isProgrammaticCameraChange = true
                        withAnimation(.easeInOut(duration: 1.5)) {
                            focusMap(onCoordinates: [featured.coordinate], singleSpan: zoomToSpan(featured.zoomLevel))
                        }

                        // Show info card after animation settles
                        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s for animation + settle
                        await MainActor.run {
                            showFeaturedCard = true
                            isProgrammaticCameraChange = false
                            isMapInitialized = true
                        }
                    } else {
                        // Returning user: use existing smart positioning
                        let initialCenter = determineInitialMapCenter()

                        withAnimation(.easeInOut(duration: 0.5)) {
                            focusMap(onCoordinates: [initialCenter.coordinate], singleSpan: initialCenter.span)
                        }

                        // Mark map as initialized after positioning
                        await MainActor.run {
                            isMapInitialized = true
                        }
                    }

                    // Refresh visible sites based on current map viewport
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await viewModel.refreshVisibleSites(in: mapRegion)
                } else {
                    // No sites, but still show the map
                    await MainActor.run {
                        isMapInitialized = true
                    }
                }
            }
            .onAppear {
                updateTabBarVisibility(for: surfaceDetent)
            }
            .onDisappear {
                NotificationCenter.default.post(name: .tabBarVisibilityShouldChange, object: nil, userInfo: ["hidden": false])
            }
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(1)
    }
    
    // MARK: - View Components
    
    private var mapView: some View {
        ZStack {
            mapLayer
            featuredDestinationOverlay
                .allowsHitTesting(showFeaturedCard)  // Fix UX-003: Disable hit test when hidden
            unifiedSurfaceOverlay
            siteCalloutOverlay          // Fix UX-004: Render callout ABOVE surface
            proximityPromptOverlay
                .allowsHitTesting(uiViewModel.proximityPrompt != nil)  // Fix UX-003: Disable hit test when hidden
            comingSoonToastOverlay
                .allowsHitTesting(showingComingSoonToast)  // Fix UX-003: Disable hit test when hidden
            overlayControls  // Fix UX-003: Render HUD controls LAST so search button is clickable
        }
    }

    // MARK: - Coming Soon Toast

    @ViewBuilder
    private var comingSoonToastOverlay: some View {
        if showingComingSoonToast {
            VStack {
                HStack(spacing: 12) {
                    Image(systemName: "hammer.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(comingSoonFeature) Coming Soon")
                            .font(.subheadline.weight(.semibold))
                        Text("This feature is under development")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .shadow(radius: 8)
                .padding(.top, safeAreaInsets.top + 60)

                Spacer()
            }
            .transition(.move(edge: .top).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation(.spring(response: 0.3)) {
                        showingComingSoonToast = false
                    }
                }
            }
        }
    }

    private func showComingSoonToast(feature: String) {
        comingSoonFeature = feature
        withAnimation(.spring(response: 0.3)) {
            showingComingSoonToast = true
        }
        Haptics.soft()
    }

    // MARK: - Site Callout Overlay

    @ViewBuilder
    private var siteCalloutOverlay: some View {
        // Fix UX-004: Removed isInspecting check - we already dismiss inspection before showing callout
        // The onChange(of: uiViewModel.mode) handler will dismiss callout if user enters inspect mode
        if showCallout, let site = calloutSite {
            GeometryReader { geometry in
                let surfaceHeight = surfaceDetent.height(in: geometry.size.height)
                let topInset = geometry.safeAreaInsets.top
                let availableHeight = geometry.size.height - surfaceHeight - topInset
                // Position callout in the center of the visible map area
                let centerY = topInset + (availableHeight / 2)

                SiteCalloutCard(
                    site: site,
                    mediaURL: calloutMediaURL,
                    onViewDetails: {
                        dismissCallout()
                        uiViewModel.send(.openSiteInspection(site.id))
                        surfaceDetent = .medium
                    },
                    onLogDive: {
                        dismissCallout()
                        startLiveLog(at: site)
                    },
                    onDismiss: {
                        dismissCallout()
                    }
                )
                .padding(.horizontal, 24)
                .position(x: geometry.size.width / 2, y: centerY)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showCallout)
            .task(id: calloutSite?.id) {
                await fetchCalloutMedia()
            }
        }
    }

    private func fetchCalloutMedia() async {
        guard let siteId = calloutSite?.id else {
            calloutMediaURL = nil
            return
        }
        let mediaRepo = SiteMediaRepository(database: AppDatabase.shared)
        do {
            if let media = try mediaRepo.fetchMedia(for: siteId) {
                calloutMediaURL = URL(string: media.url)
            } else {
                calloutMediaURL = nil
            }
        } catch {
            calloutMediaURL = nil
        }
    }

    private func dismissCallout() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            showCallout = false
            calloutSite = nil
            calloutMediaURL = nil
        }
    }

    // MARK: - Featured Destination Overlay

    @ViewBuilder
    private var featuredDestinationOverlay: some View {
        if showFeaturedCard, let destination = featuredService.activeDestination {
            VStack {
                FeaturedDestinationCard(
                    destination: destination,
                    onDismiss: {
                        showFeaturedCard = false
                        featuredService.completeFeaturedExperience()
                    }
                )
                .padding(.top, safeAreaInsets.top + 8)
                Spacer()
            }
            .transition(.opacity.combined(with: .move(edge: .top)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showFeaturedCard)
        }
    }

    // MARK: - Proximity Prompt Overlay (Step 12)

    @ViewBuilder
    private var proximityPromptOverlay: some View {
        if let prompt = uiViewModel.proximityPrompt, !prompt.isDismissed {
            VStack {
                Spacer()
                ProximityPromptCard(
                    state: prompt,
                    onAccept: {
                        uiViewModel.send(.acceptProximityPrompt)
                        startLiveLog(at: prompt.site)
                        Haptics.success()
                    },
                    onDismiss: {
                        uiViewModel.send(.dismissProximityPrompt)
                        Haptics.soft()
                    }
                )
                .padding(.horizontal, 16)
                .padding(.bottom, surfaceDetent.height(in: UIScreen.main.bounds.height) + 12)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: uiViewModel.proximityPrompt != nil)
        }
    }

    // MARK: - Unified Surface (Step 10)

    private var unifiedSurfaceOverlay: some View {
        UnifiedBottomSurface(
            mode: uiModeBinding,
            detent: $surfaceDetent,
            exploreFilters: $uiViewModel.exploreFilters,
            filterLens: filterLensBinding,
            filteredSites: unifiedFilteredSites,
            allSites: viewModel.sites,
            isLoading: viewModel.loading,
            dataViewModel: viewModel,
            onSiteTap: { site in
                uiViewModel.send(.openSiteInspection(site.id))
                surfaceDetent = .medium
                focusMap(on: [site], singleSpan: 2.5)
                Haptics.soft()
            },
            onDismissInspect: {
                uiViewModel.send(.closeSiteInspection)
                surfaceDetent = .peek
            },
            onApplyFilters: {
                uiViewModel.send(.closeFilter(apply: true))
                surfaceDetent = .peek
            },
            onCancelFilters: {
                uiViewModel.send(.closeFilter(apply: false))
                surfaceDetent = .peek
            },
            onSearchSelect: { site in
                // Dismiss keyboard first
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )

                // Animate transition to inspect mode
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    uiViewModel.send(.closeSearch(selectedSite: site.id))
                    surfaceDetent = .medium
                }

                // Focus map after brief delay for smoother animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    focusMap(on: [site], singleSpan: 2.5)
                }

                Haptics.soft()
            },
            onSearchSelectCountry: { country in
                // Dismiss keyboard first
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )

                // Navigate to country level in hierarchy
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    uiViewModel.send(.drillDownToCountry(country.id))
                    uiViewModel.send(.closeSearch(selectedSite: nil))
                    surfaceDetent = .medium
                }

                // Auto-zoom to country bounds
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let bounds = try? geographyRepository.fetchBounds(countryId: country.id) {
                        focusMap(onBounds: bounds)
                    }
                }

                Haptics.soft()
            },
            onSearchSelectRegion: { regionName, sites in
                // Dismiss keyboard first
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )

                // Navigate to explore mode showing region sites
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    uiViewModel.send(.drillDownToRegion(regionName))
                    uiViewModel.send(.closeSearch(selectedSite: nil))
                    surfaceDetent = .medium
                }

                // Auto-zoom to region sites
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !sites.isEmpty {
                        let coordinates = sites.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        focusMap(onCoordinates: coordinates)
                    }
                }

                Haptics.soft()
            },
            onSearchSelectArea: { areaName, regionName, sites in
                // Dismiss keyboard first
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )

                // Navigate to explore mode showing area sites
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    uiViewModel.send(.drillDownToArea(areaName, region: regionName))
                    uiViewModel.send(.closeSearch(selectedSite: nil))
                    surfaceDetent = .medium
                }

                // Auto-zoom to area sites
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if !sites.isEmpty {
                        let coordinates = sites.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        focusMap(onCoordinates: coordinates)
                    }
                }

                Haptics.soft()
            },
            onSearchSelectSpecies: { species in
                // Dismiss keyboard first
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil
                )

                // Show sites where this species can be found
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    uiViewModel.send(.showSpeciesSites(species.id))
                    uiViewModel.send(.closeSearch(selectedSite: nil))
                    surfaceDetent = .medium
                }

                // Auto-zoom to sites with this species
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if let sites = try? siteRepository.fetchForSpecies(species.id), !sites.isEmpty {
                        let coordinates = sites.map {
                            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                        }
                        focusMap(onCoordinates: coordinates)
                    }
                }

                Haptics.soft()
            },
            onOpenFilter: {
                uiViewModel.send(.openFilter)
                surfaceDetent = .expanded
            },
            onOpenSearch: {
                uiViewModel.send(.openSearch)
                surfaceDetent = .expanded
            },
            onNavigateUp: {
                uiViewModel.send(.navigateUp)
            },
            onResetToWorld: {
                uiViewModel.send(.resetToWorld)
            },
            onDrillDown: { regionId in
                uiViewModel.send(.drillDownToRegion(regionId))
            },
            onOpenPlan: { _ in
                showComingSoonToast(feature: "Trip Planning")
            },
            onAddSiteToPlan: { _ in
                showComingSoonToast(feature: "Trip Planning")
            },
            onRemoveSiteFromPlan: { _ in
                showComingSoonToast(feature: "Trip Planning")
            },
            onClosePlan: {
                // No-op since plan mode is not implemented
            },
            onUpdateSearchQuery: { query in
                uiViewModel.send(.updateSearchQuery(query))
            }
        )
    }

    /// Binding for MapUIMode that dispatches actions on set.
    private var uiModeBinding: Binding<MapUIMode> {
        Binding(
            get: { uiViewModel.mode },
            set: { _ in
                // Mode is only changed via send() actions, not direct binding
            }
        )
    }

    /// Binding for filter lens that syncs with the explore context.
    private var filterLensBinding: Binding<FilterLens?> {
        Binding(
            get: { uiViewModel.exploreContext?.filterLens },
            set: { newLens in
                if let lens = newLens {
                    uiViewModel.send(.applyFilterLens(lens))
                } else {
                    uiViewModel.send(.clearFilterLens)
                }
            }
        )
    }

    private func currentViewportRegion() -> MKCoordinateRegion {
        if let viewport = lastViewport {
            return MapBounds(viewport: viewport).toRegion()
        }
        return mapRegion
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            beginProgrammaticCameraChange()
            let region = currentViewportRegion()
            let minimumSpan = 0.02
            let newSpan = MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta / 1.5, minimumSpan),
                longitudeDelta: max(region.span.longitudeDelta / 1.5, minimumSpan)
            )
            mapRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            beginProgrammaticCameraChange()
            let region = currentViewportRegion()
            let maximumLatSpan = 180.0
            let maximumLonSpan = 360.0
            let newSpan = MKCoordinateSpan(
                latitudeDelta: min(region.span.latitudeDelta * 1.5, maximumLatSpan),
                longitudeDelta: min(region.span.longitudeDelta * 1.5, maximumLonSpan)
            )
            mapRegion = MKCoordinateRegion(center: region.center, span: newSpan)
        }
    }
    
    private var mapLayer: some View {
        ZStack {
            // Use native MapKit instead of MapLibre (iOS 18 compatibility)
            nativeMapKitView
                .opacity(isMapInitialized ? 1 : 0)

            // Show loading indicator until map is positioned
            if !isMapInitialized {
                Color(.systemBackground)
                    .ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading dive sites...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var nativeMapKitView: some View {
        NativeMapView(
            sites: viewModel.sites,
            region: $mapRegion,
            onSelect: { siteId in
                // Wrap in DispatchQueue.main.async to avoid SwiftUI state mutation during view update
                DispatchQueue.main.async {
                    if let site = viewModel.sites.first(where: { $0.id == siteId }) {
                        selectedSiteIdForScroll = site.id

                        // Close any existing inspection first (mutual exclusivity)
                        if uiViewModel.mode.isInspecting {
                            uiViewModel.send(.closeSiteInspection)
                        }

                        // Show callout card
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            calloutSite = site
                            showCallout = true
                            surfaceDetent = .peek
                        }
                        Haptics.soft()
                    }
                }
            },
            onRegionChange: { newRegion in
                // Wrap in DispatchQueue.main.async to avoid SwiftUI state mutation during view update
                DispatchQueue.main.async {
                    if !isProgrammaticCameraChange {
                        followMap = false

                        // Dismiss callout on pan
                        if showCallout {
                            dismissCallout()
                        }

                        // Dismiss featured card
                        if featuredService.isShowingFeatured {
                            showFeaturedCard = false
                            featuredService.completeFeaturedExperience()
                        }
                    }

                    // Update visible sites
                    let bounds = MapBounds(
                        minLatitude: newRegion.center.latitude - newRegion.span.latitudeDelta / 2,
                        maxLatitude: newRegion.center.latitude + newRegion.span.latitudeDelta / 2,
                        minLongitude: newRegion.center.longitude - newRegion.span.longitudeDelta / 2,
                        maxLongitude: newRegion.center.longitude + newRegion.span.longitudeDelta / 2
                    )
                    viewModel.scheduleRefreshVisibleSites(bounds: bounds)
                    viewModel.saveMapState(center: newRegion.center, zoom: 10)  // Approximate zoom

                    // Post viewport change for Wildlife "This area" filter
                    NotificationCenter.default.post(
                        name: .mapViewportChanged,
                        object: nil,
                        userInfo: ["bounds": bounds]
                    )
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var mapLibreView: some View {
        DiveMapView(
            annotations: mapLibreAnnotations,
            initialCamera: diveMapCamera,
            layerSettings: DiveMapLayerSettings(
                showClusters: viewModel.layerSettings.showClusters,
                showStatusGlows: viewModel.layerSettings.showStatusGlows,
                colorByDifficulty: viewModel.layerSettings.colorByDifficulty
            ),
            onSelect: { identifier in
                // Wrap in DispatchQueue.main.async to avoid SwiftUI state mutation during view update
                DispatchQueue.main.async {
                    if let site = viewModel.sites.first(where: { $0.id == identifier }) {
                        selectedSiteIdForScroll = site.id

                        // Close any existing inspection first (mutual exclusivity)
                        if uiViewModel.mode.isInspecting {
                            uiViewModel.send(.closeSiteInspection)
                        }

                        // Show callout card instead of immediately opening inspection
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            calloutSite = site
                            showCallout = true
                            surfaceDetent = .peek  // Ensure bottom sheet is minimal
                        }
                        focusMap(on: [site], singleSpan: 2.5)
                        Haptics.soft()
                        return
                    }
                    if identifier.hasPrefix("shop:"),
                       let rawId = identifier.split(separator: ":").last {
                        let shopId = String(rawId)
                        if let shop = viewModel.shops.first(where: { $0.id == shopId }) {
                            handleShopTap(shop)
                        }
                    }
                }
            },
            onRegionChange: { viewport in
                // Wrap in DispatchQueue.main.async to avoid SwiftUI state mutation during view update
                DispatchQueue.main.async {
                    lastViewport = viewport
                    let bounds = MapBounds(viewport: viewport)
                    mapRegion = bounds.toRegion()
                    if !isProgrammaticCameraChange {
                        followMap = false

                        // Dismiss callout on user pan
                        if showCallout {
                            dismissCallout()
                        }

                        // Dismiss featured card on user interaction
                        if featuredService.isShowingFeatured {
                            showFeaturedCard = false
                            featuredService.completeFeaturedExperience()
                        }

                        // Dismiss inspection if site scrolls offscreen
                        if let siteId = uiViewModel.inspectedSiteId,
                           let site = viewModel.sites.first(where: { $0.id == siteId }) {
                            let isVisible = viewport.minLatitude <= site.latitude &&
                                            site.latitude <= viewport.maxLatitude &&
                                            viewport.minLongitude <= site.longitude &&
                                            site.longitude <= viewport.maxLongitude
                            if !isVisible {
                                uiViewModel.send(.closeSiteInspection)
                                surfaceDetent = .peek
                            }
                        }
                    }
                    viewModel.scheduleRefreshVisibleSites(bounds: bounds)

                    // US-2: Save map state for persistence
                    let center = CLLocationCoordinate2D(
                        latitude: (viewport.minLatitude + viewport.maxLatitude) / 2,
                        longitude: (viewport.minLongitude + viewport.maxLongitude) / 2
                    )
                    viewModel.saveMapState(center: center, zoom: diveMapCamera.zoomLevel)
                }
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var overlayControls: some View {
        GeometryReader { geo in
            let metrics = overlayMetrics(for: geo.size)
            ZStack(alignment: .topLeading) {
                topOverlay

#if DEBUG
                if showDebugHUD {
                    debugHUD
                        .padding(.leading, 16)
                        .padding(.top, safeAreaInsets.top + 16)
                        .allowsHitTesting(true)
                }
#endif

                if surfaceDetent != .expanded,
                   geofenceManager.isAtDiveSite,
                   let site = geofenceManager.currentDiveSite {
                    VStack {
                        Spacer()
                            .allowsHitTesting(false)
                        contextualStartButton(for: site)
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(metrics.bottomPadding, surfaceDetent.height(in: geo.size.height) + safeAreaInsets.bottom + 40))
                            .allowsHitTesting(true)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - HUD Overlay

    private var topOverlay: some View {
        ZStack {
            // Search button - top right
            VStack {
                HStack {
                    Spacer()
                        .allowsHitTesting(false)  // Allow map touches to pass through
                    MinimalSearchButton {
                        uiViewModel.send(.openSearch)
                        surfaceDetent = .expanded
                        Haptics.soft()
                    }
                    // Note: 44x44 tap target now defined in MinimalSearchButton itself
                    .padding(.trailing, safeAreaInsets.trailing + 16)
                    .padding(.top, safeAreaInsets.top + 8)
                    .zIndex(1000)  // Fix UX-003: Ensure search button is above all other overlays
                }
                Spacer()
                    .allowsHitTesting(false)  // Allow map touches to pass through
            }
            .allowsHitTesting(true)  // Fix UX-003: Ensure VStack receives hits
            .zIndex(1000)  // Fix UX-003: Ensure search overlay is on top

            // Context label - bottom left, above surface
            VStack {
                Spacer()
                    .allowsHitTesting(false)  // Allow map touches to pass through
                HStack {
                    ContextLabel(
                        mode: uiViewModel.mode,
                        siteCount: hudSiteCount,
                        isFiltered: hudIsFiltered,
                        siteName: inspectedSiteName
                    )
                    .padding(.leading, safeAreaInsets.leading + 16)
                    .padding(.bottom, surfaceDetent.height(in: UIScreen.main.bounds.height) + 12)
                    Spacer()
                        .allowsHitTesting(false)  // Allow map touches to pass through
                }
            }
            .animation(.easeOut(duration: 0.2), value: uiViewModel.mode)
        }
    }

    private var inspectedSiteName: String? {
        guard let siteId = uiViewModel.inspectedSiteId else { return nil }
        return viewModel.sites.first(where: { $0.id == siteId })?.name
    }

    private var hudSiteCount: Int {
        baseSitesForCounts.count
    }

    private var hudIsFiltered: Bool {
        uiViewModel.exploreFilters.isActive || uiViewModel.exploreContext?.filterLens != nil
    }

    private var bottomGlow: some View {
        // Simplified - removed decorative circle that caused visual noise
        LinearGradient(
            colors: [
                Color.clear,
                Color.abyss.opacity(0.6)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 80)
        .allowsHitTesting(false)
        .transition(.opacity)
    }

    private func contextualStartButton(for site: DiveSite) -> some View {
        Button(action: { startLiveLog(at: site) }) {
            HStack(spacing: 14) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start a Dive")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                    Text(site.name)
                        .font(.caption)
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(
                LinearGradient(
                    colors: [Color.oceanBlue, Color.diveTeal],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.oceanBlue.opacity(0.35), radius: 16, y: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start a dive at \(site.name)")
    }

    private func recenterMap() {
        guard let last = lastFittedRegion else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            mapRegion = last
            followMap = true
        }
        Haptics.tap()
    }
    
    private func updateTabBarVisibility(for detent: SurfaceDetent) {
        let shouldHide = detent == .expanded
        NotificationCenter.default.post(name: .tabBarVisibilityShouldChange, object: nil, userInfo: ["hidden": shouldHide])
    }


    /// Sync filter lens to the selected My Sites tab using new unified state.
    private func syncFilterLensToMySitesTab(_ tab: MySitesTab) {
        switch tab {
        case .timeline:
            uiViewModel.send(.applyFilterLens(.logged))
        case .saved:
            uiViewModel.send(.applyFilterLens(.saved))
        case .planned:
            uiViewModel.send(.applyFilterLens(.planned))
        }
    }

    private func clearDiscoverFilters() {
        withAnimation(.spring(response: 0.3)) {
            // Reset filters using new unified state
            uiViewModel.exploreFilters.reset()
            uiViewModel.send(.resetToWorld)
            entityTab = .sites
        }
        followMap = true
        fitToVisible()
    }

    private func clearMySitesFilters() {
        withAnimation(.spring(response: 0.3)) {
            mySitesTab = .saved
            syncFilterLensToMySitesTab(.saved)
            // Reset hierarchy using new unified state
            uiViewModel.send(.resetToWorld)
        }
        followMap = true
        fitToVisible()
    }
    
    private func startLiveLog(at site: DiveSite) {
        Haptics.soft()
        NotificationCenter.default.post(name: .startLiveLogRequested, object: site)
    }

    private func searchCurrentViewport() {
        guard let viewport = lastViewport else {
            followMap = true
                fitToVisible()
            return
        }
        Task {
            await viewModel.refreshVisibleSites(in: MapBounds(viewport: viewport).toRegion())
            await MainActor.run {
                withAnimation(.spring(response: 0.25)) {
                    followMap = true
                            }
            }
        }
    }

private struct MapBackgroundOverlay: View {
    let appearance: MapAppearance

    var body: some View {
        LinearGradient(
            colors: [
                appearance.backgroundTop,
                appearance.backgroundBottom
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

private func overlayMetrics(for size: CGSize) -> OverlayMetrics {
    // Exclusion zones
    let effectiveTabBarHeight = surfaceDetent == .peek ? tabBarHeight : 0
    let bottomNavExclusion = safeAreaInsets.bottom + effectiveTabBarHeight + 12
    let navPadding = bottomNavExclusion + 16
    let surfaceClearance = surfaceDetent.height(in: size.height) + 16

    let bottomPadding = max(16, max(navPadding, surfaceClearance))

    return OverlayMetrics(bottomPadding: bottomPadding)
}

// MARK: - Action Handlers
    
    private func handleRegionTap(_ region: Region) {
        withAnimation(.spring(response: 0.25)) {
            // Use new unified state for hierarchy navigation
            uiViewModel.send(.drillDownToRegion(region.id))
            entityTab = .areas
        }
        Haptics.tap()
    }

    private func handleAreaTap(_ area: Area) {
        let areaSites = viewModel.sites.filter { parseAreaCountry($0.location).area == area.name }
        withAnimation(.easeInOut(duration: 0.3)) {
            focusMap(on: areaSites)
            // Use new unified state for hierarchy navigation
            uiViewModel.send(.drillDownToArea(area.id, region: nil))
            surfaceDetent = .medium
            followMap = true
            entityTab = .sites
        }
        Haptics.tap()
    }
    
    private func handleSiteTap(_ site: DiveSite) {
        Haptics.soft()
        selectedSite = site
        selectedSiteIdForScroll = site.id
        withAnimation(.easeInOut(duration: 0.3)) {
            focusMap(on: [site], singleSpan: 2.5)
            surfaceDetent = .medium
        }
    }

    private func handleShopTap(_ shop: MapDiveShop) {
        guard let coordinate = shop.coordinate else { return }
        Haptics.soft()
        beginProgrammaticCameraChange()
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
            followMap = true
            surfaceDetent = .medium
        }
    }
    

    // MARK: - Smart Initial Camera (US-1, US-2)

    private func determineInitialMapCenter() -> (coordinate: CLLocationCoordinate2D, span: Double) {
        // 0. US-2: Check for persisted map state (returning user)
        if let lastState = viewModel.loadLastMapState() {
            let span = zoomToSpan(lastState.zoom)
            return (lastState.center, span)
        }

        // 1. Check for saved sites (most recent visited or wishlist)
        let savedSites = viewModel.sites.filter { $0.wishlist || $0.visitedCount > 0 }
        if let mostRecent = savedSites.first {
            return (CLLocationCoordinate2D(latitude: mostRecent.latitude, longitude: mostRecent.longitude), 4.0)
        }

        // 2. Check location permission and current location
        if locationService.authorizationStatus == .authorizedWhenInUse ||
           locationService.authorizationStatus == .authorizedAlways,
           let location = locationService.currentLocation {
            return (location.coordinate, 6.0)
        }

        // 3. Fallback: Phuket, Thailand - a beautiful diving destination
        // Shows visible land and ocean at an engaging zoom level
        return (CLLocationCoordinate2D(latitude: 8.0, longitude: 98.3), 7.0)
    }

    /// Convert zoom level to approximate span (latitude delta)
    private func zoomToSpan(_ zoom: Double) -> Double {
        // Approximate: span ≈ 360 / 2^(zoom-1)
        return 360.0 / pow(2.0, zoom - 1)
    }

    private var savedSitesList: [DiveSite] {
        let base = viewModel.visibleSites.isEmpty ? viewModel.sites : viewModel.visibleSites
        return viewModel.applyMyMapFilters(to: base)
    }
    
    private var discoverSitesList: [DiveSite] {
        let viewportSites = viewModel.visibleSites.isEmpty ? viewModel.sites : viewModel.visibleSites
        let base: [DiveSite]
        // Use new hierarchy helpers
        if let areaId = currentAreaId {
            base = viewportSites.filter { parseAreaCountry($0.location).area == areaId }
        } else if let regionId = currentRegionId {
            base = viewportSites.filter { $0.region == regionId }
        } else {
            base = viewportSites
        }
        // Apply new unified filters
        return viewModel.applyFilters(to: base, filters: uiViewModel.exploreFilters, lens: nil, hierarchy: .world)
    }

    private var discoverShopsList: [MapDiveShop] {
        var shops = viewModel.shops
        // Use new hierarchy helpers
        if let areaId = currentAreaId {
            shops = shops.filter { $0.area == areaId }
        } else if let regionId = currentRegionId {
            shops = shops.filter { $0.region == regionId }
        }
        if let viewport = lastViewport {
            shops = shops.filter { shop in
                guard let lat = shop.latitude, let lon = shop.longitude else { return false }
                return lat >= viewport.minLatitude && lat <= viewport.maxLatitude &&
                       lon >= viewport.minLongitude && lon <= viewport.maxLongitude
            }
        }
        return shops.sorted { $0.name < $1.name }
    }
    

}

// MARK: - Environment Helpers

private struct SafeAreaInsetsKey: EnvironmentKey {
    static var defaultValue: EdgeInsets {
#if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first,
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
            let insets = window.safeAreaInsets
            return EdgeInsets(top: insets.top, leading: insets.left, bottom: insets.bottom, trailing: insets.right)
        }
#endif
        return EdgeInsets()
    }
}

extension EnvironmentValues {
    var safeAreaInsets: EdgeInsets {
        get { self[SafeAreaInsetsKey.self] }
        set { self[SafeAreaInsetsKey.self] = newValue }
    }
}

// MARK: - Pin View

private struct OverlayMetrics {
    let bottomPadding: CGFloat
}

struct PinView: View {
    let site: DiveSite
    let isSelected: Bool
    
    var body: some View {
        Circle()
            .fill(pinColor)
            .frame(width: isSelected ? 32 : 24, height: isSelected ? 32 : 24)
            .overlay(
                Image(systemName: site.visitedCount > 0 ? "checkmark" : "star.fill")
                    .font(.system(size: isSelected ? 14 : 10))
                    .foregroundStyle(.white)
            )
            .shadow(radius: 4)
            .animation(.spring(response: 0.3), value: isSelected)
    }
    
    private var pinColor: Color {
        if site.visitedCount > 0 {
            return .oceanBlue  // Visited - filled blue
        } else if site.wishlist {
            return .yellow  // Wishlist - hollow star (using yellow for now)
        } else {
            return .gray.opacity(0.5)  // Unowned - muted
        }
    }
}

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

private extension Array where Element == Double {
    var average: Double {
        guard !isEmpty else { return 0 }
        return reduce(0, +) / Double(count)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

#Preview {
    NewMapView()
}
