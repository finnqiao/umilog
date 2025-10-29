import SwiftUI
import MapKit
import UmiDB
import FeatureLiveLog
import UmiDesignSystem
import DiveMap
import UmiCoreKit
import UmiLocationKit

struct MapLayerSettings: Equatable {
    var showUnderwaterGlow: Bool = true
    var showClusters: Bool = true
    var showStatusGlows: Bool = true
    var colorByDifficulty: Bool = true
}

public struct NewMapView: View {
    private let useMapLibre: Bool
    @StateObject private var viewModel = MapViewModel()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 180)
    )
    @State private var selectedSite: DiveSite?
    @State private var showingSiteDetail = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var showFilterLayers = false
    @State private var isMapFullScreen = false

    // Bottom sheet detents and behavior
    @State private var sheetDetent: SheetDetent = .peek
    @State private var isUserDraggingSheet = false
    @State private var lastMapInteractionAt = Date()
    @State private var idleCollapseTask: Task<Void, Never>?

    // Selection and syncing
    @State private var selectedSiteIdForScroll: String?
    @State private var followMap: Bool = true

    // Location (for contextual FAB)
    @ObservedObject private var locationService = LocationService.shared

    // V3 scope and entity tabs
    @State private var scope: Scope = .saved
    @State private var entityTab: EntityTab = .areas
    
    public init(useMapLibre: Bool = true) {
        self.useMapLibre = useMapLibre
    }
    
    private var primaryColor: Color { viewModel.mode == .explore ? .reef : .lagoon }

    private enum SheetDetent { case peek, half, full }

    private var baseSitesForCounts: [DiveSite] { followMap ? viewModel.visibleSites : viewModel.sites }
    private var countsText: String {
        let areas = Set(baseSitesForCounts.map { parseAreaCountry($0.location).area }).count
        let sites = baseSitesForCounts.count
        var components = ["Areas in view: \(areas)", "Sites in view: \(sites)"]
        return components.joined(separator: " • ")
    }

    private func fitToVisible() {
        focusMap(on: baseSitesForCounts)
    }
    
    private var activeFilterCount: Int {
        // Count active filters: if statusFilter is set (any value), it's 1; if exploreFilter is not .all, it's 1
        var count = 0
        // For now, assume status filter is always active if set
        // In future, we'd track which filters are actually applied
        if viewModel.exploreFilter != .all { count += 1 }
        return count
    }
    private var mapLibreAnnotations: [DiveMapAnnotation] {
        let selectedId = selectedSite?.id
        let sitesToShow = viewModel.filteredSites.isEmpty ? viewModel.sites : viewModel.filteredSites
        return sitesToShow.map { site in
            let kind: DiveMapAnnotation.Kind = site.type == .wreck ? .wreck : .site
            let status: DiveMapAnnotation.Status
            if site.visitedCount > 0 {
                status = .logged
            } else if site.wishlist {
                status = .saved
            } else {
                status = .baseline
            }
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

    private func focusMap(on sites: [DiveSite], singleSpan: Double = 4.0) {
        guard !sites.isEmpty else { return }
        if sites.count == 1, let site = sites.first {
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude),
                span: MKCoordinateSpan(latitudeDelta: singleSpan, longitudeDelta: singleSpan)
            )
            return
        }

        let latitudes = sites.map { $0.latitude }
        let longitudes = sites.map { $0.longitude }
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2.0,
            longitude: (minLon + maxLon) / 2.0
        )
        
        // Add padding for better visibility, ensure minimum span
        let latRange = maxLat - minLat
        let lonRange = maxLon - minLon
        let padding = 0.15  // 15% padding on each side
        let latSpan = max(latRange * (1.0 + padding * 2), 5.0)
        let lonSpan = max(lonRange * (1.0 + padding * 2), 8.0)
        
        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latSpan, longitudeDelta: lonSpan)
        )
    }
    private var diveMapCamera: DiveMapCamera {
        let span = mapRegion.span
        let normalizedLatitude = max(span.latitudeDelta, 1.0)
        let denominator = 30.0
        let baseZoom = 8.0 - log2(normalizedLatitude / denominator)
        let approxZoom = max(1.5, min(14.0, baseZoom))
        return DiveMapCamera(center: mapRegion.center, zoomLevel: approxZoom)
    }
    
    public var body: some View {
        mapView
            .tint(primaryColor)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button(action: { showSearch = true; Haptics.soft() }) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(Color.foam)
                        }
                        
                        Button(action: { showFilterLayers = true; Haptics.soft() }) {
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Color.foam)
                        }
                        
                        Button(action: { withAnimation(.spring(response: 0.3)) { isMapFullScreen.toggle() }; Haptics.soft() }) {
                            Image(systemName: isMapFullScreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .foregroundStyle(Color.foam)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingSiteDetail) {
                siteDetailSheet
            }
            .sheet(isPresented: $showSearch) {
                searchSheet
            }
            .sheet(isPresented: $showFilterLayers) {
                combinedFilterLayersSheet
            }
            .onChange(of: viewModel.selectedRegion) {
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.selectedArea) {
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.statusFilter) {
                focusMap(on: viewModel.filteredSites)
            }
            .onChange(of: viewModel.exploreFilter) {
                focusMap(on: viewModel.filteredSites)
            }
.onChange(of: selectedSite) {
                if let selectedSite {
                    focusMap(on: [selectedSite])
                }
            }
            .onChange(of: scope) { newScope in
                viewModel.mode = (newScope == .discover) ? .explore : .myMap
            }
            .task {
                // Load sites and center map - called once on appear
                await viewModel.loadSites()
                
                // Small delay to ensure view is laid out
                try? await Task.sleep(nanoseconds: 50_000_000)
                
                // Center map on all sites after loading
                let sitesToCenter = await MainActor.run { viewModel.sites }
                if !sitesToCenter.isEmpty {
                    focusMap(on: sitesToCenter)
                    
                    // Refresh visible sites based on current map viewport
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await viewModel.refreshVisibleSites(in: mapRegion)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilitySortPriority(1)
    }
    
    // MARK: - View Components
    
    private var mapView: some View {
        ZStack(alignment: .bottom) {
            mapLayer
            overlayControls
        }
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let newSpan = MKCoordinateSpan(
                latitudeDelta: mapRegion.span.latitudeDelta / 1.5,
                longitudeDelta: mapRegion.span.longitudeDelta / 1.5
            )
            mapRegion = MKCoordinateRegion(center: mapRegion.center, span: newSpan)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            let newSpan = MKCoordinateSpan(
                latitudeDelta: mapRegion.span.latitudeDelta * 1.5,
                longitudeDelta: mapRegion.span.longitudeDelta * 1.5
            )
            mapRegion = MKCoordinateRegion(center: mapRegion.center, span: newSpan)
        }
    }
    
    private var mapLayer: some View {
        ZStack {
            if useMapLibre {
                mapLibreView
            } else {
                mapKitView
            }
            if viewModel.layerSettings.showUnderwaterGlow {
                UnderwaterGlowOverlay()
                    .allowsHitTesting(false)
            }
        }
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
            onSelect: { siteId in
                if let site = viewModel.sites.first(where: { $0.id == siteId }) {
                    selectedSite = site
                    selectedSiteIdForScroll = site.id
                    withAnimation(.easeInOut(duration: 0.3)) {
                        focusMap(on: [site], singleSpan: 2.5)
                        sheetDetent = .half
                    }
                }
            },
            onRegionChange: { viewport in
                viewModel.scheduleRefreshVisibleSites(bounds: MapBounds(viewport: viewport))
                lastMapInteractionAt = Date()
                scheduleIdleCollapse()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
    
    private var mapKitView: some View {
        MapClusterView(
            annotations: mapKitAnnotations,
            layerSettings: viewModel.layerSettings,
            onSelect: { siteId in
                if let s = viewModel.sites.first(where: { $0.id == siteId }) {
                    selectedSite = s
                    selectedSiteIdForScroll = s.id
                    withAnimation(.easeInOut(duration: 0.3)) {
                        focusMap(on: [s], singleSpan: 2.5)
                        sheetDetent = .half
                    }
                }
            },
            onRegionChange: { region in
                viewModel.scheduleRefreshVisibleSites(in: region)
                lastMapInteractionAt = Date()
                scheduleIdleCollapse()
            },
            center: mapRegion.center
        )
        .ignoresSafeArea()
    }
    
    private var mapKitAnnotations: [SiteAnnotation] {
        viewModel.visibleSites.map { s in
            SiteAnnotation(
                id: s.id,
                coordinate: CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude),
                title: s.name,
                subtitle: s.location,
                visited: s.visitedCount > 0,
                wishlist: s.wishlist,
                difficulty: s.difficulty
            )
        }
    }
    
    private var overlayControls: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geo in
                VStack(spacing: 0) {
                    Spacer()
                    
                    if !isMapFullScreen {
                        // Caustics overlay + water gradient (very subtle animation)
                        ZStack {
                            // Deep water gradient (darkens toward bottom)
                            LinearGradient(
                                colors: [
                                    Color.black.opacity(0.0),
                                    Color.oceanBlue.opacity(0.08)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            .allowsHitTesting(false)
                            
                            // Radial caustics (subtle, animated)
                            Circle()
                                .fill(
                                    RadialGradient(
                                        gradient: Gradient(colors: [
                                            Color.diveTeal.opacity(0.04),
                                            Color.oceanBlue.opacity(0.02),
                                            Color.clear
                                        ]),
                                        center: .center,
                                        startRadius: 20,
                                        endRadius: 200
                                    )
                                )
                                .scaleEffect(1.0 + sin(Date().timeIntervalSince1970) * 0.006)
                                .frame(height: 120)
                                .allowsHitTesting(false)
                        }
                        .transition(.opacity)
                        
                        // Glass sheet with soft shadow
                        bottomSheet
                            .frame(height: sheetHeight(geo))
                            .shadow(color: Color.black.opacity(0.15), radius: 8, y: -2)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            
            // Zoom +/- buttons (bottom-right, always visible)
            if !isMapFullScreen {
                VStack(spacing: 8) {
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.foam)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.glass).stroke(Color.kelp.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.foam)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(Color.glass).stroke(Color.kelp.opacity(0.5), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.trailing, 16)
                .padding(.bottom, 100)
                .ignoresSafeArea()
            }
        }
    }
    
    // Top Pill: removed (controls moved to toolbar)
    
    private var bottomSheet: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.kelp.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 16)

            VStack(spacing: 12) {
                // Scope picker
                HStack(spacing: 16) {
                    Picker("Scope", selection: $scope) {
                        Text("Saved").tag(Scope.saved)
                        Text("Discover").tag(Scope.discover)
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.lagoon)
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                // Entity tab (Discover only)
                if scope == .discover {
                    Picker("", selection: $entityTab) {
                        Text("Areas").tag(EntityTab.areas)
                        Text("Sites").tag(EntityTab.sites)
                        Text("Shops").tag(EntityTab.shops)
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.lagoon)
                    .padding(.horizontal, 16)
                }
                
                // Chips (Discover, half/full only)
                if scope == .discover && sheetDetent != .peek && entityTab != .shops {
                    filterChipsScrollView
                }

                // List content
                tierContentView
                    .padding(.top, 8)
            }
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.foam)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.oceanBlue.opacity(0.08).blendMode(.overlay))
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
    
    private var filterChipsScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if viewModel.mode == .myMap {
                    myMapFilterChips
                } else {
                    exploreFilterChips
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var myMapFilterChips: some View {
        visitedFilterChip
        wishlistFilterChip
        plannedFilterChip
    }
    
    private var visitedFilterChip: some View {
        FilterChip(
            title: "Visited (\(viewModel.visitedCount))",
            isSelected: viewModel.statusFilter == .visited,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.statusFilter = .visited
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var wishlistFilterChip: some View {
        FilterChip(
            title: "Wishlist (\(viewModel.wishlistCount))",
            isSelected: viewModel.statusFilter == .wishlist,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.statusFilter = .wishlist
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    private var plannedFilterChip: some View {
        FilterChip(
            title: "Planned (\(viewModel.plannedCount))",
            isSelected: viewModel.statusFilter == .planned,
            action: {
                withAnimation(.spring(response: 0.25)) {
                    viewModel.statusFilter = .planned
                    viewModel.tier = .sites
                    viewModel.selectedRegion = nil
                    viewModel.selectedArea = nil
                }
                Haptics.tap()
            },
            primaryColor: primaryColor
        )
    }
    
    @ViewBuilder
    private var exploreFilterChips: some View {
        allFilterChip
        nearbyFilterChip
        popularFilterChip
        beginnerFilterChip
        staticFilterChips
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
    
    private var tierContentView: some View {
        VStack(spacing: 12) {
            if scope == .discover {
                BreadcrumbHeader(viewModel: viewModel)
                    .padding(.horizontal, 16)
                
                switch entityTab {
                case .areas:
                    areasTierView
                case .sites:
                    SitesListView(
                        sites: discoverSitesList,
                        selectedSiteId: selectedSiteIdForScroll,
                        onSiteTap: handleSiteTap
                    )
                    .frame(maxHeight: 260)
                case .shops:
                    ShopsListView(
                        shops: shopsForCurrentSelection,
                        onShopTap: handleShopTap
                    )
                    .frame(maxHeight: 260)
                }
            } else {
                SitesListView(
                    sites: savedSitesList,
                    selectedSiteId: selectedSiteIdForScroll,
                    onSiteTap: handleSiteTap
                )
                .frame(maxHeight: 260)
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
                onSiteTap: handleSiteTap
            )
        }
        .frame(maxHeight: 260)
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

private struct UnderwaterGlowOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color.oceanBlue.opacity(colorScheme == .dark ? 0.35 : 0.20),
                Color.diveTeal.opacity(colorScheme == .dark ? 0.28 : 0.16)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.overlay)
        .ignoresSafeArea()
    }
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
        }
    }
    

    // MARK: - Sheet helpers
    private func sheetHeight(_ geo: GeometryProxy) -> CGFloat {
        let h = geo.size.height
        switch sheetDetent {
        case .peek: return max(h * 0.18, 140)
        case .half: return h * 0.5
        case .full: return h * 0.9
        }
    }

    private func scheduleIdleCollapse() {
        idleCollapseTask?.cancel()
        idleCollapseTask = Task { [lastMapInteractionAt] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if Date().timeIntervalSince(lastMapInteractionAt) >= 1.9 && !isUserDraggingSheet {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.25)) { sheetDetent = .peek }
                }
            }
        }
    }

    private var savedSitesList: [DiveSite] {
        let base = followMap ? viewModel.visibleSites : viewModel.sites
        return viewModel.applyMyMapFilters(to: base)
    }
    
    private var discoverSitesList: [DiveSite] {
        let base: [DiveSite]
        if let area = viewModel.selectedArea {
            base = viewModel.sites.filter { parseAreaCountry($0.location).area == area.name }
        } else if let region = viewModel.selectedRegion {
            base = viewModel.sites.filter { $0.region == region.name }
        } else if followMap {
            base = viewModel.visibleSites
        } else {
            base = viewModel.sites
        }
        return viewModel.applyExploreFilters(to: base)
    }
    
    
}

// MARK: - Pin View

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
        case .regions: return "\(viewModel.regions.count) regions"
        case .areas: return "\(viewModel.areasInSelectedRegion.count) areas"
        case .sites: return "\(viewModel.visibleSites.count) sites"
        }
    }
}

struct AreasListView: View {
    let areas: [Area]
    let onAreaTap: (Area) -> Void
    var body: some View {
        ScrollView { LazyVStack(spacing: 0) {
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
        }}
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
    @State private var flashId: String?
    
    var body: some View {
        ScrollViewReader { proxy in
            if sites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    Text("No items")
                        .font(.subheadline)
                        .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(sites) { site in
                            SiteRow(site: site, isHighlighted: flashId == site.id)
                                .id(site.id)
                                .onTapGesture { onSiteTap(site) }
                        }
                    }
                }
            }
        }
        .onChange(of: selectedSiteId) { id in
            guard let id else { return }
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

// MARK: - View Model

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
}

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
    @Published var regions: [Region] = []
    @Published var loading: Bool = false
    @Published var visibleSites: [DiveSite] = []
    
    private var wishlistObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard
    private static let modeKey = "map.filter.mode"
    private static let statusFilterKey = "map.filter.status"
    private static let exploreFilterKey = "map.filter.explore"
    
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
        return groups.map { entry in
            let areaName = entry.key
            let country = parseAreaCountry(entry.value.first!.location).country
            return Area(
                id: areaName,
                name: areaName,
                country: country,
                siteCount: entry.value.count,
                shopCount: 0
            )
        }
            .sorted { $0.name < $1.name }
    }
    
    private func saveFilterPreferences() {
        defaults.set(mode == .explore ? "explore" : "myMap", forKey: Self.modeKey)
        defaults.set(statusFilterString(statusFilter), forKey: Self.statusFilterKey)
        defaults.set(exploreFilterString(exploreFilter), forKey: Self.exploreFilterKey)
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
        do {
            do {
                try DatabaseSeeder.seedIfNeeded()
            } catch {
                print("Failed to seed database before loading sites: \(error)")
            }
            let fetchedSites = try siteRepo.fetchAll()
            let regionNames = Set(fetchedSites.map { $0.region })
            let computedRegions = regionNames.map { name in
                let regionSites = fetchedSites.filter { $0.region == name }
                return Region(
                    id: name,
                    name: name,
                    totalSites: regionSites.count,
                    visitedCount: regionSites.filter { $0.visitedCount > 0 }.count,
                    shopCount: 0
                )
            }.sorted { $0.name < $1.name }
            
            await MainActor.run {
                self.sites = fetchedSites
                self.regions = computedRegions
                // Initialize visible sites to all sites
                self.visibleSites = fetchedSites
            }
        } catch {
            print("Failed to load sites: \(error)")
            await MainActor.run {
                self.sites = []
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

// MARK: - Models

enum MapMode {
    case myMap, explore
}

enum StatusFilter {
    case visited, wishlist, planned
}

enum ExploreFilter {
    case all, nearby, popular, beginner, wrecks
}

enum Tier {
    case regions, areas, sites
}

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

// MARK: - Helper Extensions

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
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

// Helper to parse "Area, Country" from location
fileprivate func parseAreaCountry(_ location: String) -> (area: String, country: String) {
    let parts = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    if parts.count >= 2 { return (String(parts[0]), String(parts[1])) }
    return (location, "")
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

// MARK: - V3 Enums
enum Scope { case saved, discover }
enum EntityTab { case areas, sites }

#Preview {
    NewMapView()
}
