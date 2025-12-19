import SwiftUI
import MapKit  // Only for MKCoordinateRegion/Span types - not using MapKit views
import UmiDB
import FeatureLiveLog
import UmiDesignSystem
import DiveMap
import UmiCoreKit
import UmiLocationKit
import UIKit

typealias MapDiveShop = UmiDB.DiveShop

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
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    private let tabBarHeight: CGFloat = 72
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
    )
    @State private var selectedSite: DiveSite?
    @State private var previewSite: DiveSite?  // US-8: Lightweight preview before full detail
    @State private var showingSiteDetail = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showFilterLayers = false

    // Bottom sheet detents and behavior
    @State private var sheetDetent: SheetDetent = .peek
    @State private var lastNonPeekDetent: SheetDetent = .half
    @State private var activeSheetHeight: CGFloat = 0

    // New unified surface state
    @State private var surfaceDetent: SurfaceDetent = .peek
    @State private var controlRailHeight: CGFloat = 0
    @State private var isProgrammaticCameraChange = false
    @State private var searchPillVisible = false
    @State private var searchPillHideTask: Task<Void, Never>?
#if DEBUG
    @State private var showDebugHUD = false
#endif
    @GestureState private var sheetDragTranslation: CGFloat = 0
    @State private var featureFlags = MapFeatureFlags()

    // Selection and syncing
    @State private var selectedSiteIdForScroll: String?
    @State private var followMap: Bool = true

    // Track camera fits for recenter
    @State private var lastFittedRegion: MKCoordinateRegion?
    @State private var lastViewport: DiveMapViewport?

    // Location (for contextual FAB)
    @ObservedObject private var locationService = LocationService.shared
    @ObservedObject private var geofenceManager = GeofenceManager.shared

    // V3 scope and entity tabs
    @State private var scope: Scope = .discover
    @State private var entityTab: EntityTab = .sites
    @State private var mySitesTab: MySitesTab = .saved
    @State private var showShops: Bool = false
    
    public init(appearance: MapAppearance = .default) {
        self.appearance = appearance
    }
    
    private var primaryColor: Color { viewModel.mode == .explore ? .reef : .lagoon }

    private enum SheetDetent { case peek, half, full }

    private var baseSitesForCounts: [DiveSite] {
        let viewportSites = viewModel.visibleSites.isEmpty ? viewModel.sites : viewModel.visibleSites
        if scope == .discover {
            return viewModel.applyExploreFilters(to: viewportSites)
        } else {
            return viewModel.applyMyMapFilters(to: viewportSites)
        }
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
        viewModel.selectedRegion != nil || viewModel.selectedArea != nil
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
            if viewModel.exploreFilter != .all {
                parts.append(viewModel.exploreFilter.displayName)
            }
            if showShops {
                parts.append("Shops")
            }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        } else {
            switch mySitesTab {
            case .timeline:
                return nil
            case .saved:
                return StatusFilter.wishlist.displayName
            case .planned:
                return StatusFilter.planned.displayName
            }
        }
    }

    private func fitToVisible() {
        hideSearchPrompt()
        followMap = true
        if scope == .discover && entityTab == .sites && showShops {
            focusMap(onShops: discoverShopsList, including: baseSitesForCounts)
            return
        }
        focusMap(on: baseSitesForCounts)
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if viewModel.exploreFilter != .all { count += 1 }
        if showShops { count += 1 }
        return count
    }

    // Use the correct list for annotations to avoid accidental filtering to wishlist-only
    private var annotationSites: [DiveSite] {
        if scope == .discover {
            if entityTab == .sites || viewModel.selectedArea != nil {
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

        if scope == .discover && entityTab == .sites && showShops {
            annotations += shopAnnotations
        }

        return annotations
    }

#if DEBUG
    private var sheetDetentLabel: String {
        switch sheetDetent {
        case .peek: return "peek"
        case .half: return "half"
        case .full: return "full"
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

    private var railStateLabel: String {
        featureFlags.useRail ? "visible" : "hidden"
    }

    private var debugHUD: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sheet: \(sheetDetentLabel) • Rail: \(railStateLabel)")
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
                if viewModel.selectedArea != nil {
                    Button("Fit area") { fitSelectedArea() }
                }
                Button("Reset world") { resetCameraToWorld() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.mini)
            Divider()
            Toggle("Rail", isOn: $featureFlags.useRail)
                .toggleStyle(.switch)
            Toggle("Detents", isOn: $featureFlags.sheetDetents)
                .toggleStyle(.switch)
            Toggle("Chips @ peek", isOn: $featureFlags.showChipsAtPeek)
                .toggleStyle(.switch)
            Toggle("Clusters", isOn: $featureFlags.clusterOn)
                .toggleStyle(.switch)
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
            return DiveMapAnnotation(
                id: site.id,
                coordinate: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude),
                kind: kind,
                status: status,
                difficulty: difficulty,
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
            if let region = viewModel.selectedRegion?.name {
                return baseSites.filter { $0.region == region }
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
        hideSearchPrompt()
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

#if DEBUG
    private func fitAllSites() {
        focusMap(on: viewModel.sites)
    }

    private func fitSelectedArea() {
        guard let area = viewModel.selectedArea else { return }
        let areaSites = viewModel.sites.filter { parseAreaCountry($0.location).area == area.name }
        focusMap(on: areaSites.isEmpty ? viewModel.sites : areaSites)
    }

    private func resetCameraToWorld() {
        hideSearchPrompt()
        beginProgrammaticCameraChange()
        mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
        )
        followMap = true
        sheetDetent = .peek
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
            // US-8: Site preview card overlay
            .overlay(alignment: .bottom) {
                if let site = previewSite {
                    SitePreviewCard(
                        site: site,
                        onTap: {
                            selectedSite = site
                            previewSite = nil
                            showingSiteDetail = true
                        },
                        onDismiss: {
                            withAnimation(.easeOut(duration: 0.2)) {
                                previewSite = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, activeSheetHeight + 16)
                }
            }
            .sheet(isPresented: $showingSiteDetail) { siteDetailSheet }
            .sheet(isPresented: $showSearch) { searchSheet }
            .sheet(isPresented: $showFilterLayers) { combinedFilterLayersSheet }
            .onChange(of: viewModel.selectedRegion) { _ in
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.selectedArea) { _ in
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.statusFilter) { _ in
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.exploreFilter) { _ in
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: selectedSite) { _ in
                if let selectedSite { focusMap(on: [selectedSite]) }
            }
            .onChange(of: scope) { newScope in
                viewModel.mode = (newScope == .discover) ? .explore : .myMap
                if newScope == .discover {
                    entityTab = .sites
                } else {
                    showShops = false
                    syncStatusFilterToMySitesTab(mySitesTab)
                }
            }
            .onChange(of: mySitesTab) { newValue in
                syncStatusFilterToMySitesTab(newValue)
            }
            .onChange(of: featureFlags.clusterOn) { newValue in
                viewModel.layerSettings.showClusters = newValue
            }
            .onChange(of: featureFlags.sheetDetents) { enabled in
                if !enabled {
                    sheetDetent = .peek
                    lastNonPeekDetent = .half
                    updateTabBarVisibility(for: .peek)
                }
            }
            .onChange(of: sheetDetent) { newDetent in
                if featureFlags.sheetDetents && newDetent != .peek {
                    lastNonPeekDetent = newDetent
                }
                updateTabBarVisibility(for: newDetent)
            }
            .task {
                // Load sites and center map - called once on appear
                await viewModel.loadSites()

                // Small delay to ensure view is laid out
                try? await Task.sleep(nanoseconds: 50_000_000)

                // US-1: Smart initial positioning
                let sitesToCenter = await MainActor.run { viewModel.sites }
                if !sitesToCenter.isEmpty {
                    let initialCenter = determineInitialMapCenter()

                    withAnimation(.easeInOut(duration: 0.5)) {
                        focusMap(onCoordinates: [initialCenter.coordinate], singleSpan: initialCenter.span)
                    }

                    // Refresh visible sites based on current map viewport
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await viewModel.refreshVisibleSites(in: mapRegion)

                    lastNonPeekDetent = .half
                }
            }
            .onAppear {
                updateTabBarVisibility(for: sheetDetent)
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
            overlayControls
            if featureFlags.useNewSurface {
                unifiedSurfaceOverlay
                proximityPromptOverlay
            } else {
                bottomSheetOverlay
            }
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

    private var bottomSheetOverlay: some View {
        GeometryReader { geo in
            let containerHeight = geo.size.height
            let baseHeight = sheetHeight(for: sheetDetent, containerHeight: containerHeight)
            let dragOffset = featureFlags.sheetDetents ? sheetDragOffset(for: sheetDragTranslation, containerHeight: containerHeight) : 0
            let currentHeight = max(0, baseHeight - dragOffset)
            let _ = updateActiveSheetHeightIfNeeded(currentHeight)

            let sheetView = bottomSheet
                .frame(height: baseHeight)
                .offset(y: dragOffset)
                .shadow(color: Color.black.opacity(0.18), radius: 10, y: -4)
                .transition(.move(edge: .bottom).combined(with: .opacity))

            VStack(spacing: 0) {
                Spacer()
                    .allowsHitTesting(false)
                bottomGlow
                    .allowsHitTesting(false)
                if featureFlags.sheetDetents {
                    sheetView
                        .overlay(alignment: .top) {
                            Color.clear
                                .frame(height: 44)
                                .contentShape(Rectangle())
                                .gesture(sheetDragGesture(containerHeight: containerHeight))
                        }
                } else {
                    sheetView
                }
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }

    // MARK: - New Unified Surface (Step 10)

    private var unifiedSurfaceOverlay: some View {
        UnifiedBottomSurface(
            mode: uiModeBinding,
            detent: $surfaceDetent,
            exploreFilters: $uiViewModel.exploreFilters,
            filterLens: filterLensBinding,
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
                uiViewModel.send(.closeSearch(selectedSite: site.id))
                surfaceDetent = .medium
                focusMap(on: [site], singleSpan: 2.5)
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
            onDrillDown: { regionId in
                uiViewModel.send(.drillDownToRegion(regionId))
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
            MapBackgroundOverlay(appearance: appearance)
            mapLibreView
        }
    }
    
    private var mapLibreView: some View {
        DiveMapView(
            annotations: mapLibreAnnotations,
            initialCamera: diveMapCamera,
            layerSettings: DiveMapLayerSettings(
                showClusters: featureFlags.clusterOn && viewModel.layerSettings.showClusters,
                showStatusGlows: viewModel.layerSettings.showStatusGlows,
                colorByDifficulty: viewModel.layerSettings.colorByDifficulty
            ),
            onSelect: { identifier in
                if let site = viewModel.sites.first(where: { $0.id == identifier }) {
                    selectedSiteIdForScroll = site.id

                    // Step 10.3: Route to new surface when enabled
                    if featureFlags.useNewSurface {
                        uiViewModel.send(.openSiteInspection(site.id))
                        surfaceDetent = .medium
                        focusMap(on: [site], singleSpan: 2.5)
                        Haptics.soft()
                    } else {
                        // US-8: Show preview card first, not full detail
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            previewSite = site
                            focusMap(on: [site], singleSpan: 2.5)
                        }
                        Haptics.soft()
                    }
                    return
                }
                if identifier.hasPrefix("shop:"),
                   let rawId = identifier.split(separator: ":").last {
                    let shopId = String(rawId)
                    if let shop = viewModel.shops.first(where: { $0.id == shopId }) {
                        handleShopTap(shop)
                    }
                }
            },
            onRegionChange: { viewport in
                lastViewport = viewport
                let bounds = MapBounds(viewport: viewport)
                mapRegion = bounds.toRegion()
                if !isProgrammaticCameraChange {
                    followMap = false
                    showSearchPrompt()

                    // Step 10.4: Dismiss inspection if site scrolls offscreen
                    if featureFlags.useNewSurface,
                       let siteId = uiViewModel.inspectedSiteId,
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
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private var overlayControls: some View {
        GeometryReader { geo in
            let metrics = overlayMetrics(for: geo.size)
            ZStack(alignment: .topLeading) {
                topOverlay

                if metrics.showSearchPill {
                    Button(action: searchCurrentViewport) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Search this area")
                                .fontWeight(.semibold)
                                .lineLimit(1)
                        }
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .frame(height: 36)
                        .frame(maxWidth: 240)
                        .background(Capsule().fill(Color.glass))
                        .foregroundStyle(Color.foam)
                    }
                    .allowsHitTesting(true)
                    .position(x: geo.size.width / 2,
                              y: metrics.searchPillY)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

#if DEBUG
                if showDebugHUD {
                    debugHUD
                        .padding(.leading, 16)
                        .padding(.top, safeAreaInsets.top + 16)
                        .allowsHitTesting(true)
                }
#endif

                VStack {
                    Spacer()
                        .allowsHitTesting(false)
                    HStack {
                        Spacer()
                            .allowsHitTesting(false)
                        if featureFlags.useRail {
                            mapControlRail()
                                .opacity(metrics.railOpacity)
                                .padding(.trailing, safeAreaInsets.trailing + 16)
                                .padding(.bottom, metrics.bottomPadding)
                                .allowsHitTesting(true)
                        }
                    }
                }
                .frame(width: geo.size.width, height: geo.size.height)

                if sheetDetent != .full,
                   geofenceManager.isAtDiveSite,
                   let site = geofenceManager.currentDiveSite {
                    VStack {
                        Spacer()
                            .allowsHitTesting(false)
                        contextualStartButton(for: site)
                            .padding(.horizontal, 24)
                            .padding(.bottom, max(metrics.bottomPadding, activeSheetHeight + safeAreaInsets.bottom + 40))
                            .allowsHitTesting(true)
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    // MARK: - HUD Overlay (Step 11)

    @ViewBuilder
    private var topOverlay: some View {
        if featureFlags.useNewSurface {
            hudOverlay
        } else {
            EmptyView()
        }
    }

    private var hudOverlay: some View {
        ZStack {
            // Search button - top right
            VStack {
                HStack {
                    Spacer()
                    MinimalSearchButton {
                        uiViewModel.send(.openSearch)
                        surfaceDetent = .expanded
                        Haptics.soft()
                    }
                    .padding(.trailing, safeAreaInsets.trailing + 16)
                    .padding(.top, safeAreaInsets.top + 8)
                }
                Spacer()
            }

            // Context label - bottom left, above surface
            VStack {
                Spacer()
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

    private func mapControlRail() -> some View {
        VStack(spacing: 12) {
            MapControlButton(
                icon: "magnifyingglass",
                label: "Search dive sites",
                action: {
                    showSearch = true
                    Haptics.soft()
                }
            )
            MapControlButton(
                icon: "slider.horizontal.3",
                label: "Filters and layers",
                isActive: activeFilterCount > 0,
                badge: activeFilterCount > 0 ? abbreviatedCount(activeFilterCount) : nil,
                announcesState: true,
                action: {
                    showFilterLayers = true
                    Haptics.soft()
                }
            )
            if isOffCenter {
                MapControlButton(
                    icon: "scope",
                    label: "Recenter map",
                    action: recenterMap
                )
            }
            MapControlButton(
                icon: sheetDetent == .peek ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left",
                label: sheetDetent == .peek ? "Expand sheet" : "Collapse sheet",
                action: toggleSheetDetent
            )
            .opacity(featureFlags.sheetDetents ? 1.0 : 0.4)
            .allowsHitTesting(featureFlags.sheetDetents)
            MapControlButton(
                icon: "plus",
                label: "Zoom in",
                action: {
                    zoomIn()
                    Haptics.tap()
                }
            )
            MapControlButton(
                icon: "minus",
                label: "Zoom out",
                action: {
                    zoomOut()
                    Haptics.tap()
                }
            )
            RailAccessoryButton(
                icon: "magnifyingglass.circle",
                accessibilityLabel: "Search this area",
                size: 36,
                action: {
                    Haptics.tap()
                    searchCurrentViewport()
                }
            )
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.glass)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.foam.opacity(0.12), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 14, y: 6)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear { controlRailHeight = proxy.size.height }
                    .onChange(of: proxy.size.height) { newValue in
                        controlRailHeight = newValue
                    }
            }
        )
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
        hideSearchPrompt()
        Haptics.tap()
    }
    
    private func toggleSheetDetent() {
        guard featureFlags.sheetDetents else { return }
        withAnimation(.spring(response: 0.3)) {
            if sheetDetent == .peek {
                sheetDetent = lastNonPeekDetent
            } else {
                lastNonPeekDetent = sheetDetent
                sheetDetent = .peek
            }
        }
        Haptics.soft()
    }

    private func updateTabBarVisibility(for detent: SheetDetent) {
        let shouldHide = featureFlags.sheetDetents ? (detent != .peek) : false
        NotificationCenter.default.post(name: .tabBarVisibilityShouldChange, object: nil, userInfo: ["hidden": shouldHide])
    }

    private func sheetHeight(for detent: SheetDetent, containerHeight: CGFloat) -> CGFloat {
        switch detent {
        case .peek:
            return max(containerHeight * 0.24, 160)
        case .half:
            return containerHeight * 0.60
        case .full:
            return containerHeight
        }
    }

    private func sheetDragOffset(for translation: CGFloat, containerHeight: CGFloat) -> CGFloat {
        let baseHeight = sheetHeight(for: sheetDetent, containerHeight: containerHeight)
        let minHeight = sheetHeight(for: .peek, containerHeight: containerHeight)
        let maxHeight = sheetHeight(for: .full, containerHeight: containerHeight)
        let clampedHeight = min(max(baseHeight - translation, minHeight), maxHeight)
        return baseHeight - clampedHeight
    }

    private func sheetDragGesture(containerHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($sheetDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                finalizeSheetDrag(translation: value.translation.height, containerHeight: containerHeight)
            }
    }

    private func finalizeSheetDrag(translation: CGFloat, containerHeight: CGFloat) {
        guard featureFlags.sheetDetents else {
            sheetDetent = .peek
            return
        }
        let baseHeight = sheetHeight(for: sheetDetent, containerHeight: containerHeight)
        let minHeight = sheetHeight(for: .peek, containerHeight: containerHeight)
        let halfHeight = sheetHeight(for: .half, containerHeight: containerHeight)
        let fullHeight = sheetHeight(for: .full, containerHeight: containerHeight)

        let clampedHeight = min(max(baseHeight - translation, minHeight), fullHeight)
        let targets: [(SheetDetent, CGFloat)] = [(.peek, minHeight), (.half, halfHeight), (.full, fullHeight)]
        let targetDetent = targets.min { abs(clampedHeight - $0.1) < abs(clampedHeight - $1.1) }?.0 ?? sheetDetent

        guard targetDetent != sheetDetent else { return }
        withAnimation(.spring(response: 0.3)) {
            sheetDetent = targetDetent
        }
    }

    @discardableResult
    private func updateActiveSheetHeightIfNeeded(_ newValue: CGFloat) -> Bool {
        let clamped = max(0, newValue)
        if abs(activeSheetHeight - clamped) > 1 {
            DispatchQueue.main.async {
                activeSheetHeight = clamped
            }
            return true
        }
        return false
    }

    private func syncStatusFilterToMySitesTab(_ tab: MySitesTab) {
        switch tab {
        case .timeline:
            viewModel.statusFilter = .visited
        case .saved:
            viewModel.statusFilter = .wishlist
        case .planned:
            viewModel.statusFilter = .planned
        }
    }
    
    private func clearDiscoverFilters() {
        withAnimation(.spring(response: 0.3)) {
            viewModel.exploreFilter = .all
            viewModel.selectedRegion = nil
            viewModel.selectedArea = nil
            viewModel.tier = .regions
            entityTab = .sites
            showShops = false
        }
        hideSearchPrompt()
        followMap = true
        fitToVisible()
    }
    
    private func clearMySitesFilters() {
        withAnimation(.spring(response: 0.3)) {
            mySitesTab = .saved
            syncStatusFilterToMySitesTab(.saved)
            viewModel.selectedRegion = nil
            viewModel.selectedArea = nil
            viewModel.tier = .regions
        }
        hideSearchPrompt()
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
            hideSearchPrompt()
            fitToVisible()
            return
        }
        Task {
            await viewModel.refreshVisibleSites(in: MapBounds(viewport: viewport).toRegion())
            await MainActor.run {
                withAnimation(.spring(response: 0.25)) {
                    followMap = true
                    hideSearchPrompt()
                }
            }
        }
    }

    private var bottomSheet: some View {
        VStack(spacing: 0) {
            ZStack {
                Capsule()
                    .fill(Color.kelp.opacity(0.35))
                    .frame(width: 36, height: 4)
            }
            .frame(height: 44)

            bottomSheetContent
                .padding(.bottom, 12)
        }
        .foregroundStyle(Color.foam)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.oceanBlue.opacity(0.62).opacity(0.62))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Material.thin)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.oceanBlue.opacity(0.2), lineWidth: 1)
                )
        )
        .transition(.move(edge: .bottom))
    }
    
    private var bottomSheetContent: some View {
        VStack(spacing: 16) {
            sheetPrimaryRow
            sheetContextRow

            if scope == .discover && (sheetDetent != .peek || featureFlags.showChipsAtPeek) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(filtersScopeLabel)
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                        .padding(.horizontal, 16)
                    filterChipsScrollView
                        .frame(height: 36)
                }
            }

            if let summary = filterSummaryText {
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.horizontal, 16)

            tierContentView
        }
    }

    private var sheetPrimaryRow: some View {
        HStack(spacing: 12) {
            // Phase 4: Search button (accessible when rail is removed)
            Button(action: { showSearch = true; Haptics.soft() }) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.foam)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(Color.glass))
                    .overlay(Circle().stroke(Color.foam.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search dive sites")

            Picker("Scope", selection: $scope) {
                Text("Discover").tag(Scope.discover)
                Text("My Dive Sites").tag(Scope.saved)
            }
            .pickerStyle(.segmented)
            .tint(Color.lagoon)
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            Spacer(minLength: 8)
            Button(action: { fitToVisible(); Haptics.soft() }) {
                Text(currentCountLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Fit to results")
            .accessibilityValue(currentCountLabel)
        }
        .padding(.horizontal, 16)
    }

    private var sheetContextRow: some View {
        HStack(spacing: 12) {
            if scope == .discover {
                Picker("", selection: $entityTab) {
                    Text("Areas").tag(EntityTab.areas)
                    Text("Sites").tag(EntityTab.sites)
                }
                .pickerStyle(.segmented)
                .tint(Color.lagoon)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            } else {
                Picker("", selection: $mySitesTab) {
                    Text("Timeline").tag(MySitesTab.timeline)
                    Text("Saved").tag(MySitesTab.saved)
                    Text("Planned").tag(MySitesTab.planned)
                }
                .pickerStyle(.segmented)
                .tint(Color.lagoon)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }
    
    private var filterChipsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { exploreFilterChips }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var exploreFilterChips: some View {
        allFilterChip
        nearbyFilterChip
        popularFilterChip
        beginnerFilterChip
        staticFilterChips
        shopsFilterChip
    }
    
    private var allFilterChip: some View {
        FilterChip(
            title: "All",
            isSelected: viewModel.exploreFilter == .all,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.exploreFilter = .all
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var nearbyFilterChip: some View {
        FilterChip(
            title: "Nearby",
            isSelected: viewModel.exploreFilter == .nearby,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.exploreFilter = .nearby
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var popularFilterChip: some View {
        FilterChip(
            title: "Popular",
            isSelected: viewModel.exploreFilter == .popular,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.exploreFilter = .popular
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var beginnerFilterChip: some View {
        FilterChip(
            title: "Beginner",
            isSelected: viewModel.exploreFilter == .beginner,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.exploreFilter = .beginner
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var staticFilterChips: some View {
        FilterChip(
            title: "Wrecks",
            isSelected: viewModel.exploreFilter == .wrecks,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.exploreFilter = .wrecks
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }

    private var shopsFilterChip: some View {
        FilterChip(
            title: "Shops",
            isSelected: showShops,
            action: {
                withAnimation(.spring(response: 0.2)) {
                    showShops.toggle()
                }
                Haptics.soft()
            },
            primaryColor: primaryColor
        )
    }
    
    private var tierContentView: some View {
        VStack(spacing: 12) {
            if viewModel.loading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            if scope == .discover {
                if shouldShowBreadcrumb {
                    BreadcrumbHeader(viewModel: viewModel)
                        .padding(.horizontal, 16)
                }
                
                switch entityTab {
                case .areas:
                    areasTierView
                case .sites:
                    SitesListView(
                        sites: discoverSitesList,
                        selectedSiteId: selectedSiteIdForScroll,
                        onSiteTap: handleSiteTap,
                        limit: sheetDetent == .peek ? 2 : nil,
                        scrollDisabled: sheetDetent == .peek,
                        emptyState: discoverSitesEmptyState
                    )
                    if showShops {
                        if !discoverSitesList.isEmpty {
                            Divider()
                                .padding(.horizontal, 16)
                        }
                        ShopsListView(
                            shops: discoverShopsList,
                            onShopTap: handleShopTap,
                            limit: sheetDetent == .peek ? 2 : nil,
                            scrollDisabled: sheetDetent == .peek,
                            emptyState: discoverShopsEmptyState
                        )
                    }
                }
            } else {
                SitesListView(
                    sites: savedSitesList,
                    selectedSiteId: selectedSiteIdForScroll,
                    onSiteTap: handleSiteTap,
                    limit: sheetDetent == .peek ? 2 : nil,
                    scrollDisabled: sheetDetent == .peek,
                    emptyState: mySitesEmptyState
                )
            }
        }
    }
    
    @ViewBuilder
    private var areasTierView: some View {
        switch viewModel.tier {
        case .regions:
            RegionsListView(
                regions: viewModel.regions,
                selectedRegion: Binding(
                    get: { viewModel.selectedRegion },
                    set: { newValue in viewModel.selectedRegion = newValue }
                ),
                onRegionTap: handleRegionTap
            )
        case .areas:
            AreasListView(
                areas: viewModel.areasInSelectedRegion,
                onAreaTap: handleAreaTap
            )
        case .sites:
            SitesListView(
                sites: discoverSitesList,
                selectedSiteId: selectedSiteIdForScroll,
                onSiteTap: handleSiteTap,
                limit: sheetDetent == .peek ? 2 : nil,
                scrollDisabled: sheetDetent == .peek,
                emptyState: discoverSitesEmptyState
            )
        }
    }
    
    
    @ViewBuilder
    private var siteDetailSheet: some View {
        if let site = selectedSite {
            SiteDetailSheet(site: site, mode: viewModel.mode)
        }
    }
    
    private var searchSheet: some View {
        SearchSheet(searchText: $searchText, sites: viewModel.sites) { site in
            selectedSite = site
            selectedSiteIdForScroll = site.id
            withAnimation(.easeInOut(duration: 0.3)) {
                focusMap(on: [site], singleSpan: 2.5)
                sheetDetent = .half
                lastNonPeekDetent = .half
            }
            showSearch = false
        }
    }
    
    private var filterSheet: some View {
        FilterSheet(
            mode: $viewModel.mode,
            statusFilter: $viewModel.statusFilter,
            exploreFilter: $viewModel.exploreFilter,
            onDismiss: { /* deprecated in favor of combined sheet */ }
        )
        .presentationDetents([.medium])
    }

    private var layersSheet: some View {
        LayerSheet(layerSettings: $viewModel.layerSettings, onDismiss: { /* deprecated in favor of combined sheet */ })
            .presentationDetents([.medium])
    }

    private var combinedFilterLayersSheet: some View {
        CombinedFilterLayersSheet(
            mode: $viewModel.mode,
            statusFilter: $viewModel.statusFilter,
            exploreFilter: $viewModel.exploreFilter,
            layerSettings: $viewModel.layerSettings,
            onDismiss: { showFilterLayers = false }
        )
        .presentationDetents([.medium])
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
    let topSafe = safeAreaInsets.top + 12
    let sheetTopY = max(topSafe + 44, size.height - activeSheetHeight)

    // Exclusion zones
    let effectiveTabBarHeight = sheetDetent == .peek ? tabBarHeight : 0
    let bottomNavExclusion = safeAreaInsets.bottom + effectiveTabBarHeight + 12
    let navPadding = bottomNavExclusion + 16
    let sheetClearance = (activeSheetHeight > 0 ? activeSheetHeight : 0) + 16

    // Base bottom padding keeps the rail out of BottomNav ∪ SheetTop with 16pt inset
    let rawBottomPadding = max(16, max(navPadding, sheetClearance))

    // Prevent the rail from climbing into the top safe area when the sheet is full
    let maxBottomPadding: CGFloat
    if controlRailHeight > 0 {
        maxBottomPadding = max(16, size.height - (topSafe + controlRailHeight + 16))
    } else {
        maxBottomPadding = max(16, rawBottomPadding)
    }
    let bottomPadding = min(rawBottomPadding, maxBottomPadding)

    let railOpacity = sheetDetent == .full ? 0.6 : 1.0

    // Search pill placement relative to the live sheet top
    let pillHeight: CGFloat = 36
    let pillOffset: CGFloat = 10
    let desiredCenter = sheetTopY - (pillHeight / 2) - pillOffset
    let minimumCenter = topSafe + pillHeight / 2 + 20
    let clampedCenter = min(sheetTopY - (pillHeight / 2) - 4, max(minimumCenter, desiredCenter))
    let verticalGap = clampedCenter - pillHeight / 2 - topSafe
    let showSearchPill = searchPillVisible && sheetDetent != .full && verticalGap >= 56

    return OverlayMetrics(bottomPadding: bottomPadding,
                          railOpacity: railOpacity,
                          showSearchPill: showSearchPill,
                          searchPillY: clampedCenter)
}

// MARK: - Action Handlers
    
    private func handleRegionTap(_ region: Region) {
        withAnimation(.spring(response: 0.25)) {
            viewModel.selectedRegion = region
            viewModel.selectedArea = nil
            viewModel.tier = .areas
            entityTab = .areas
        }
        Haptics.tap()
    }
    
    private func handleAreaTap(_ area: Area) {
        let areaSites = viewModel.sites.filter { parseAreaCountry($0.location).area == area.name }
        withAnimation(.easeInOut(duration: 0.3)) {
            focusMap(on: areaSites)
            viewModel.selectedArea = area
            sheetDetent = .half
            hideSearchPrompt()
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
            sheetDetent = .half
            lastNonPeekDetent = .half
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
            hideSearchPrompt()
            followMap = true
            sheetDetent = .half
            lastNonPeekDetent = .half
        }
    }
    

    // MARK: - Sheet helpers
    private func showSearchPrompt() {
        searchPillHideTask?.cancel()
        searchPillVisible = true
        searchPillHideTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                searchPillVisible = false
            }
        }
    }

    private func hideSearchPrompt() {
        searchPillHideTask?.cancel()
        searchPillHideTask = nil
        searchPillVisible = false
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

        // 3. Fallback: Cabo San Lucas (popular dive region) - zoomed out to see land
        return (CLLocationCoordinate2D(latitude: 22.89, longitude: -109.92), 1.8)
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
        if let area = viewModel.selectedArea {
            base = viewportSites.filter { parseAreaCountry($0.location).area == area.name }
        } else if let region = viewModel.selectedRegion {
            base = viewportSites.filter { $0.region == region.name }
        } else {
            base = viewportSites
        }
        return viewModel.applyExploreFilters(to: base)
    }

    private var discoverShopsList: [MapDiveShop] {
        var shops = viewModel.shops
        if let area = viewModel.selectedArea {
            shops = shops.filter { $0.area == area.name }
        } else if let region = viewModel.selectedRegion {
            shops = shops.filter { $0.region == region.name }
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

private struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.mist)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.foam)
            Text(message)
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.mist)
            if let primaryTitle, let primaryAction {
                Button(action: primaryAction) {
                    Text(primaryTitle)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.reef.opacity(0.8)))
                        .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
            }
            if let secondaryTitle, let secondaryAction {
                Button(action: secondaryAction) {
                    Text(secondaryTitle)
                        .font(.footnote)
                        .underline()
                        .foregroundStyle(Color.foam.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }
}

struct EmptyStateConfiguration {
    let icon: String
    let title: String
    let message: String
    var primaryTitle: String? = nil
    var primaryAction: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
}

fileprivate func abbreviatedCount(_ value: Int) -> String {
    guard value >= 1_000 else { return "\(value)" }
    let formatted = Double(value) / 1_000
    let text = String(format: "%.1fk", formatted)
    return text.replacingOccurrences(of: ".0k", with: "k")
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

private struct MapControlButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var badge: String? = nil
    var announcesState: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(isActive ? Color.oceanBlue.opacity(0.9) : Color.glass)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.foam.opacity(isActive ? 0.4 : 0.18), lineWidth: 1)
                    )
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.foam)
                    )
                if let badge {
                    Text(badge)
                        .font(.caption2.weight(.bold))
                        .padding(4)
                        .background(Circle().fill(Color.reef))
                        .foregroundStyle(Color.white)
                        .offset(x: 16, y: -16)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(Text(announcesState ? (isActive ? "On" : "Off") : ""))
    }
}

private struct RailAccessoryButton: View {
    let icon: String
    let accessibilityLabel: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color.glass)
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .stroke(Color.foam.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.foam)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

private struct MapFeatureFlags {
    var useRail: Bool = true
    var sheetDetents: Bool = true
    var showChipsAtPeek: Bool = false
    var clusterOn: Bool = true
    var useNewSurface: Bool = true  // Step 10: New unified bottom surface
}

private struct OverlayMetrics {
    let bottomPadding: CGFloat
    let railOpacity: Double
    let showSearchPill: Bool
    let searchPillY: CGFloat
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

// MARK: - Filter Chips

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var primaryColor: Color
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? Color.foam : Color.mist)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? primaryColor.opacity(0.95) : Color.glass)
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? primaryColor.opacity(0.9) : Color.kelp.opacity(0.4), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .shadow(color: isSelected ? primaryColor.opacity(0.25) : .clear, radius: 6, y: 3)
        .accessibilityLabel(title)
        .accessibilityHint(isSelected ? "Filter active" : "Tap to activate filter")
    }
}

// MARK: - Breadcrumb Header & Areas

struct BreadcrumbHeader: View {
    @ObservedObject var viewModel: MapViewModel
    var body: some View {
        HStack(spacing: 8) {
            // Breadcrumb
            HStack(spacing: 6) {
                Text("Regions")
                    .foregroundStyle(viewModel.tier == .regions ? Color.lagoon : Color.mist)
                    .onTapGesture { viewModel.resetToRegions() }
                Text("›").foregroundStyle(Color.mist.opacity(0.6))
                Text(viewModel.selectedRegion?.name ?? "Areas")
                    .foregroundStyle(viewModel.tier == .areas ? Color.lagoon : Color.mist)
                    .onTapGesture {
                        if viewModel.selectedRegion != nil {
                            viewModel.resetToAreas()
                        }
                    }
                Text("›").foregroundStyle(Color.mist.opacity(0.6))
                Text("Sites")
                    .foregroundStyle(viewModel.tier == .sites ? Color.lagoon : Color.mist)
            }
            Spacer()
            // Counts
            Text(countText)
                .font(.caption)
                .foregroundStyle(Color.mist)
        }
    }
    private var countText: String {
        switch viewModel.tier {
        case .regions: return "\(abbreviatedCount(viewModel.regions.count)) regions"
        case .areas: return "\(abbreviatedCount(viewModel.areasInSelectedRegion.count)) areas"
        case .sites: return "\(abbreviatedCount(viewModel.filteredSites.count)) sites"
        }
    }
}

struct AreasListView: View {
    let areas: [Area]
    let onAreaTap: (Area) -> Void
    var body: some View {
        if areas.isEmpty {
            EmptyStateView(
                icon: "mappin.slash",
                title: "No areas yet",
                message: "Pick a region or clear filters to browse dive areas."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(areas) { area in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(area.name).font(.body)
                                    .accessibilityLabel("Area: \(area.name)")
                                Text(summary(for: area))
                                    .font(.caption).foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                                    .accessibilityLabel(accessibilitySummary(for: area))
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(.secondary)
                                .accessibilityLabel("Open area")
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { onAreaTap(area) }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
    
    private func summary(for area: Area) -> String {
        var components: [String] = []
        if !area.country.isEmpty {
            components.append(area.country)
        }
        components.append("\(area.siteCount) sites")
        if area.shopCount > 0 {
            components.append("\(area.shopCount) shops")
        }
        return components.joined(separator: " · ")
    }
    
    private func accessibilitySummary(for area: Area) -> String {
        var sentence = "Located in \(area.country.isEmpty ? "this region" : area.country) with \(area.siteCount) dive sites"
        if area.shopCount > 0 {
            sentence += " and \(area.shopCount) dive shops"
        }
        return sentence
    }
}
// MARK: - Regions List

struct RegionsListView: View {
    let regions: [Region]
    @Binding var selectedRegion: Region?
    var onRegionTap: (Region) -> Void
    
    var body: some View {
        if regions.isEmpty {
            EmptyStateView(
                icon: "globe.europe.africa",
                title: "No regions found",
                message: "Zoom out or clear filters to explore all regions."
            )
        } else {
            ScrollView {
                VStack(spacing: 0) {
                    Text("All Regions")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    
                    Text(summaryLine)
                        .font(.subheadline)
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)
                    
                    ForEach(regions) { region in
                        RegionRow(region: region, isSelected: selectedRegion?.id == region.id)
                            .contentShape(Rectangle())
                            .onTapGesture { onRegionTap(region) }
                    }
                }
            }
        }
    }
    
    private var summaryLine: String {
        guard !regions.isEmpty else { return "No regions yet" }
        let visitedTotal = regions.reduce(0) { $0 + $1.visitedCount }
        let sitesTotal = regions.reduce(0) { $0 + $1.totalSites }
        let shopTotal = regions.reduce(0) { $0 + $1.shopCount }
        var parts = ["\(visitedTotal)/\(sitesTotal) visited"]
        if shopTotal > 0 {
            parts.append("\(shopTotal) shops")
        }
        return parts.joined(separator: " • ")
    }
}

struct RegionRow: View {
    let region: Region
    var isSelected: Bool = false
    
    var body: some View {
        HStack {
            Circle()
                .fill(region.visitedCount > 0 ? Color.oceanBlue : Color.gray.opacity(0.3))
                .frame(width: 8, height: 8)
                .accessibilityLabel(region.visitedCount > 0 ? "Visited" : "Not visited")
            
            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(.body)
                    .accessibilityLabel("Region: \(region.name)")
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .accessibilityLabel(accessibilityDetail)
            }
            
            Spacer()
            
            if region.visitedCount > 0 {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                    .accessibilityLabel("Has visited sites")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.glass.opacity(0.6) : Color.clear)
        )
        .accessibilityElement(children: .combine)
    }
    
    private var detailText: String {
        let visited = "\(region.visitedCount)/\(region.totalSites) visited"
        guard region.shopCount > 0 else { return visited }
        return "\(visited) • \(region.shopCount) shops"
    }
    
    private var accessibilityDetail: String {
        if region.shopCount > 0 {
            return "\(region.visitedCount) of \(region.totalSites) sites visited, \(region.shopCount) dive shops"
        }
        return "\(region.visitedCount) of \(region.totalSites) sites visited"
    }
}

// MARK: - Sites List

struct SitesListView: View {
    let sites: [DiveSite]
    let selectedSiteId: String?
    let onSiteTap: (DiveSite) -> Void
    var limit: Int? = nil
    var scrollDisabled: Bool = false
    var emptyState: EmptyStateConfiguration? = nil
    @State private var flashId: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            let displayed = limit.map { Array(sites.prefix($0)) } ?? sites
            if sites.isEmpty {
                if let emptyState {
                    EmptyStateView(
                        icon: emptyState.icon,
                        title: emptyState.title,
                        message: emptyState.message,
                        primaryTitle: emptyState.primaryTitle,
                        primaryAction: emptyState.primaryAction,
                        secondaryTitle: emptyState.secondaryTitle,
                        secondaryAction: emptyState.secondaryAction
                    )
                } else {
                    EmptyStateView(
                        icon: "tray",
                        title: "No sites found",
                        message: "Clear filters or zoom out to reveal more dive sites."
                    )
                }
            } else if displayed.isEmpty {
                EmptyStateView(
                    icon: "arrow.up.left.and.arrow.down.right",
                    title: "Expand to see more",
                    message: "Pull the sheet up or zoom the map to browse sites here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(displayed) { site in
                            SiteRow(site: site, isHighlighted: flashId == site.id)
                                .id(site.id)
                                .onTapGesture { onSiteTap(site) }
                        }
                    }
                }
                .scrollDisabled(scrollDisabled)
            }
        }
        // Scroll to selection when a pin is tapped
        .onChange(of: selectedSiteId) { newId in
            guard let id = newId else { return }
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.3)) {
                    flashId = id
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.3)) { flashId = nil }
            }
        }
    }
}

struct ShopsListView: View {
    let shops: [MapDiveShop]
    let onShopTap: (MapDiveShop) -> Void
    var limit: Int? = nil
    var scrollDisabled: Bool = false
    var emptyState: EmptyStateConfiguration? = nil
    
    private var displayedShops: [MapDiveShop] {
        guard let limit else { return shops }
        return Array(shops.prefix(limit))
    }
    
    var body: some View {
        if shops.isEmpty {
            if let emptyState {
                EmptyStateView(
                    icon: emptyState.icon,
                    title: emptyState.title,
                    message: emptyState.message,
                    primaryTitle: emptyState.primaryTitle,
                    primaryAction: emptyState.primaryAction,
                    secondaryTitle: emptyState.secondaryTitle,
                    secondaryAction: emptyState.secondaryAction
                )
            } else {
                EmptyStateView(
                    icon: "building.2",
                    title: "No shops found",
                    message: "Zoom out or clear filters to see nearby dive shops."
                )
            }
        } else if displayedShops.isEmpty {
            EmptyStateView(
                icon: "arrow.up.left.and.arrow.down.right",
                title: "Expand to see more",
                message: "Pull the sheet up or zoom the map to browse dive shops in this area."
            )
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(displayedShops) { shop in
                        ShopRow(shop: shop)
                            .contentShape(Rectangle())
                            .onTapGesture { onShopTap(shop) }
                    }
                }
            }
            .scrollDisabled(scrollDisabled)
        }
    }
}


struct ShopRow: View {
    let shop: MapDiveShop
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "building.2.crop.circle")
                .font(.system(size: 24))
                .foregroundStyle(Color.oceanBlue)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(.body)
                    .foregroundStyle(Color.foam)
                    .accessibilityLabel("Shop: \(shop.name)")
                if let subtitle = subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                }
                if let detail = detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(SwiftUI.Color(UIColor.tertiaryLabel))
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
    
    private var subtitle: String? {
        var components: [String] = []
        if let area = shop.area, !area.isEmpty {
            components.append(area)
        }
        if let country = shop.country, !country.isEmpty {
            components.append(country)
        } else if let region = shop.region, !region.isEmpty {
            components.append(region)
        }
        return components.joined(separator: " · ")
    }
    
    private var detail: String? {
        if let service = shop.services.first, !service.isEmpty {
            return service
        }
        if let phone = shop.phone, !phone.isEmpty {
            return phone
        }
        if let website = shop.website, !website.isEmpty {
            return website
        }
        return nil
    }
}


struct SiteRow: View {
    let site: DiveSite
    var isHighlighted: Bool = false
    
    var statusLabel: String {
        if site.visitedCount > 0 {
            return "Logged, \(site.visitedCount) dive(s)"
        } else if site.wishlist {
            return "Wishlist"
        } else {
            return "Not visited"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(site.visitedCount > 0 ? Color.oceanBlue : (site.wishlist ? Color.yellow : Color.gray.opacity(0.3)))
                .frame(width: 8, height: 8)
                .accessibilityLabel(statusLabel)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .accessibilityLabel("Site: \(site.name)")
                
                Text(site.location)
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .accessibilityLabel("Location: \(site.location)")
                
                // Quick facts chips
                HStack(spacing: 6) {
                    QuickFactChip(text: site.difficulty.rawValue)
                    QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                    QuickFactChip(text: "\(Int(site.averageTemp))°C")
                }
                .accessibilityLabel("\(site.difficulty.rawValue) difficulty, maximum depth \(Int(site.maxDepth)) meters, average temperature \(Int(site.averageTemp)) degrees")
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.oceanBlue.opacity(isHighlighted ? 0.12 : 0.0))
        )
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
        .shadow(color: isHighlighted ? Color.oceanBlue.opacity(0.25) : .clear, radius: 8, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHighlighted)
        .accessibilityElement(children: .combine)
    }
}

struct QuickFactChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(8)
            .accessibilityLabel(text)
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

// MARK: - Sheets

struct SearchSheet: View {
    @Binding var searchText: String
    let sites: [DiveSite]
    let onSelect: (DiveSite) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var filtered: [DiveSite] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return sites }
        let q = searchText.lowercased()
        return sites.filter { $0.name.lowercased().contains(q) || $0.location.lowercased().contains(q) }
    }
    
    var body: some View {
        NavigationStack {
            List(filtered) { site in
                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name).font(.body)
                    Text(site.location).font(.caption).foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { Haptics.soft(); onSelect(site); dismiss() }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle("Search Sites")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct FilterSheet: View {
    @Binding var mode: MapMode
    @Binding var statusFilter: StatusFilter
    @Binding var exploreFilter: ExploreFilter
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("My Map").tag(MapMode.myMap)
                        Text("Explore").tag(MapMode.explore)
                    }.pickerStyle(.segmented)
                    .onChange(of: mode) {
                        Haptics.soft()
                    }
                }
                
                if mode == .myMap {
                    Section("Status Filter") {
                        Picker("Status", selection: $statusFilter) {
                            Text("Visited").tag(StatusFilter.visited)
                            Text("Wishlist").tag(StatusFilter.wishlist)
                            Text("Planned").tag(StatusFilter.planned)
                        }.pickerStyle(.segmented)
                        .onChange(of: statusFilter) {
                            Haptics.tap()
                        }
                    }
                } else {
                    Section("Explore Filter") {
                        Picker("Explore", selection: $exploreFilter) {
                            Text("All").tag(ExploreFilter.all)
                            Text("Nearby").tag(ExploreFilter.nearby)
                            Text("Popular").tag(ExploreFilter.popular)
                            Text("Beginner").tag(ExploreFilter.beginner)
                        }.pickerStyle(.segmented)
                        .onChange(of: exploreFilter) {
                            Haptics.tap()
                        }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDismiss(); dismiss() } } }
        }
    }
}

struct LayerSheet: View {
    @Binding var layerSettings: MapLayerSettings
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Visuals") {
                    Toggle("Underwater glow", isOn: $layerSettings.showUnderwaterGlow)
                        .onChange(of: layerSettings.showUnderwaterGlow) { _ in Haptics.tap() }
                    Toggle("Cluster rings", isOn: $layerSettings.showClusters)
                        .onChange(of: layerSettings.showClusters) { _ in Haptics.tap() }
                    Toggle("Status glows", isOn: $layerSettings.showStatusGlows)
                        .onChange(of: layerSettings.showStatusGlows) { _ in Haptics.tap() }
                    Toggle("Color by difficulty", isOn: $layerSettings.colorByDifficulty)
                        .onChange(of: layerSettings.colorByDifficulty) { _ in Haptics.tap() }
                }
            }
            .navigationTitle("Map Layers")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDismiss(); dismiss() } } }
        }
    }
}

struct CombinedFilterLayersSheet: View {
    @Binding var mode: MapMode
    @Binding var statusFilter: StatusFilter
    @Binding var exploreFilter: ExploreFilter
    @Binding var layerSettings: MapLayerSettings
    var onDismiss: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Mode") {
                    Picker("Mode", selection: $mode) {
                        Text("My Map").tag(MapMode.myMap)
                        Text("Explore").tag(MapMode.explore)
                    }
                    .pickerStyle(.segmented)
                }
                if mode == .myMap {
                    Section("Status Filter") {
                        Picker("Status", selection: $statusFilter) {
                            Text("Visited").tag(StatusFilter.visited)
                            Text("Wishlist").tag(StatusFilter.wishlist)
                            Text("Planned").tag(StatusFilter.planned)
                        }
                        .pickerStyle(.segmented)
                    }
                } else {
                    Section("Explore Filter") {
                        Picker("Explore", selection: $exploreFilter) {
                            Text("All").tag(ExploreFilter.all)
                            Text("Nearby").tag(ExploreFilter.nearby)
                            Text("Popular").tag(ExploreFilter.popular)
                            Text("Beginner").tag(ExploreFilter.beginner)
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Layers") {
                    Toggle("Underwater glow", isOn: $layerSettings.showUnderwaterGlow)
                    Toggle("Cluster rings", isOn: $layerSettings.showClusters)
                    Toggle("Status glows", isOn: $layerSettings.showStatusGlows)
                    Toggle("Color by difficulty", isOn: $layerSettings.colorByDifficulty)
                }
            }
            .navigationTitle("Filters & Layers")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDismiss(); dismiss() } } }
        }
    }
}

#Preview {
    NewMapView()
}
