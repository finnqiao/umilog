import SwiftUI
import MapKit
import UmiDB
import FeatureLiveLog
import UmiDesignSystem
import DiveMap
import UmiCoreKit

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
    @State private var showFilters = false
    @State private var searchText = ""
    @State private var showLayers = false
    
    // V3 scope and entity tabs
    @State private var scope: Scope = .saved
    @State private var entityTab: EntityTab = .sites
    
    public init(useMapLibre: Bool = true) {
        self.useMapLibre = useMapLibre
    }
    
    private var primaryColor: Color { viewModel.mode == .explore ? .reef : .lagoon }
    
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
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                toolbarItems
            }
            .sheet(isPresented: $showingSiteDetail) {
                siteDetailSheet
            }
            .sheet(isPresented: $showSearch) {
                searchSheet
            }
            .sheet(isPresented: $showFilters) {
                filterSheet
            }
            .sheet(isPresented: $showLayers) {
                layersSheet
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
        .overlay(alignment: .top) { topPill }
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
                    showingSiteDetail = true
                }
            },
            onRegionChange: { viewport in
                viewModel.scheduleRefreshVisibleSites(bounds: MapBounds(viewport: viewport))
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
                    showingSiteDetail = true
                }
            },
            onRegionChange: { region in
                viewModel.scheduleRefreshVisibleSites(in: region)
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
        VStack(spacing: 0) {
            Spacer()
            bottomSheet
                .presentationDetents([.height(120), .medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    // V3 Top Pill: search + filters + layers
    private var topPill: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.mist)
                Text(searchText.isEmpty ? "Search sites, shops" : searchText)
                    .foregroundStyle(searchText.isEmpty ? Color.mist : Color.foam)
                    .lineLimit(1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
            .onTapGesture { showSearch = true }
            
            Button(action: { showFilters = true; Haptics.soft() }) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(Color.foam)
            }
            .buttonStyle(.plain)
            
            Button(action: { showLayers = true; Haptics.soft() }) {
                Image(systemName: "circle.grid.2x2")
                    .foregroundStyle(Color.foam)
            }
            .buttonStyle(.plain)
        }
        .font(.system(size: 15, weight: .regular))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color.glass)
                .overlay(
                    Capsule()
                        .stroke(Color.kelp.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.top, 10)
        .padding(.horizontal, 16)
    }
    
    private var bottomSheet: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.kelp.opacity(0.35))
                .frame(width: 44, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 4)

            VStack(spacing: 16) {
                HStack {
                    Picker("Scope", selection: $scope) {
                        Text("Saved").tag(Scope.saved)
                        Text("Discover").tag(Scope.discover)
                    }
                    .pickerStyle(.segmented)
                    .tint(Color.lagoon)
                    .frame(maxWidth: 200)

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("In view")
                            .font(.caption2)
                            .foregroundStyle(Color.mist)
                        Text("\(viewModel.filteredSites.count)")
                            .font(.headline)
                            .foregroundStyle(Color.foam)
                    }
                }
                .padding(.horizontal, 16)

                Picker("Entity", selection: $entityTab) {
                    Text("Sites").tag(EntityTab.sites)
                    Text("Shops").tag(EntityTab.shops)
                }
                .pickerStyle(.segmented)
                .tint(Color.lagoon)
                .padding(.horizontal, 16)

                filterChipsScrollView

                Divider()
                    .background(Color.clear)
                    .overlay(Color.kelp.opacity(0.4))
                    .padding(.horizontal, 16)

                tierContentView
            }
            .padding(.bottom, 20)
        }
        .foregroundStyle(Color.foam)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.midnight.opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.kelp.opacity(0.45), lineWidth: 1)
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
        Group {
            FilterChip(title: "Wrecks", isSelected: false, action: {}, primaryColor: primaryColor)
            FilterChip(title: "Cave", isSelected: false, action: {}, primaryColor: primaryColor)
            FilterChip(title: "Nitrox", isSelected: false, action: {}, primaryColor: primaryColor)
        }
    }
    
    private var tierContentView: some View {
        Group {
            switch viewModel.tier {
            case .regions:
                RegionsListView(
                    regions: viewModel.regions,
                    selectedRegion: $viewModel.selectedRegion,
                    onRegionTap: handleRegionTap
                )
                .frame(maxHeight: 260)
            case .areas:
                AreasListView(
                    areas: viewModel.areasInSelectedRegion,
                    onAreaTap: handleAreaTap
                )
                .frame(maxHeight: 260)
            case .sites:
                SitesListView(
                    sites: viewModel.filteredSites,
                    onSiteTap: handleSiteTap
                )
                .frame(maxHeight: 260)
            }
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showSearch = true; Haptics.soft() }) {
                Image(systemName: "magnifyingglass")
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button(action: { showFilters = true; Haptics.soft() }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    
                    if activeFilterCount > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("\(activeFilterCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 6, y: -6)
                    }
                }
            }
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
            showingSiteDetail = true
            showSearch = false
        }
    }
    
    private var filterSheet: some View {
        FilterSheet(
            mode: $viewModel.mode,
            statusFilter: $viewModel.statusFilter,
            exploreFilter: $viewModel.exploreFilter,
            onDismiss: { showFilters = false }
        )
        .presentationDetents([.medium])
    }

    private var layersSheet: some View {
        LayerSheet(layerSettings: $viewModel.layerSettings, onDismiss: { showLayers = false })
            .presentationDetents([.medium])
    }

private struct UnderwaterGlowOverlay: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: [
                Color(white: 0.03, opacity: colorScheme == .dark ? 0.95 : 0.7),
                Color(white: 0.02, opacity: colorScheme == .dark ? 0.85 : 0.55)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .blendMode(.softLight)
        .ignoresSafeArea()
    }
}

// MARK: - Action Handlers
    
    private func handleRegionTap(_ region: Region) {
        withAnimation(.spring(response: 0.25)) {
            viewModel.selectedRegion = region
            viewModel.selectedArea = nil
            viewModel.tier = .areas
        }
        Haptics.tap()
    }
    
    private func handleAreaTap(_ area: Area) {
        withAnimation(.spring(response: 0.25)) {
            viewModel.selectedArea = area
            viewModel.tier = .sites
        }
        Haptics.tap()
    }
    
    private func handleSiteTap(_ site: DiveSite) {
        Haptics.soft()
        selectedSite = site
        showingSiteDetail = true
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
                    .onTapGesture { viewModel.tier = .regions }
                Text("›").foregroundStyle(Color.mist.opacity(0.6))
                Text(viewModel.selectedRegion?.name ?? "Areas")
                    .foregroundStyle(viewModel.tier == .areas ? Color.lagoon : Color.mist)
                    .onTapGesture { if viewModel.selectedRegion != nil { viewModel.tier = .areas } }
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
                        Text("\(area.country) · \(area.siteCount) sites")
                            .font(.caption).foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture { onAreaTap(area) }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
        }}
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
                
                Text("2/8 visited")
                    .font(.subheadline)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                ForEach(regions) { region in
                    RegionRow(region: region)
                        .contentShape(Rectangle())
                        .onTapGesture { onRegionTap(region) }
                }
            }
        }
    }
}

struct RegionRow: View {
    let region: Region
    
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
                Text("\(region.visitedCount)/\(region.totalSites) visited")
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                    .accessibilityLabel("\(region.visitedCount) of \(region.totalSites) sites visited")
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Sites List

struct SitesListView: View {
    let sites: [DiveSite]
    let onSiteTap: (DiveSite) -> Void
    
    var body: some View {
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
                        SiteRow(site: site)
                            .onTapGesture { onSiteTap(site) }
                    }
                }
            }
        }
    }
}

struct SiteRow: View {
    let site: DiveSite
    
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
            
            Button(action: { Haptics.soft() /* Present wizard from SiteDetail for now */ }) {
                Text("Log")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.oceanBlue)
                    .cornerRadius(20)
            }
            .accessibilityLabel("Log dive at \(site.name)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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
    @Published var mode: MapMode = .myMap
    @Published var statusFilter: StatusFilter = .visited
    @Published var exploreFilter: ExploreFilter = .all
    @Published var tier: Tier = .regions
    @Published var selectedRegion: Region?
    @Published var selectedArea: Area?
    @Published var layerSettings: MapLayerSettings = MapLayerSettings()
    
    @Published var sites: [DiveSite] = []
    @Published var regions: [Region] = []
    @Published var loading: Bool = false
    @Published var visibleSites: [DiveSite] = []
    
    private var wishlistObserver: NSObjectProtocol?
    
    init() {
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
        let filtered = visibleSites.filter { site in
            // Region filter
            if let region = selectedRegion, site.region != region.name { return false }
            // Area filter  
            if let area = selectedArea {
                let (siteArea, _) = parseAreaCountry(site.location)
                if siteArea != area.name { return false }
            }
            // Mode filters
            if mode == .myMap {
                switch statusFilter {
                case .visited: return site.visitedCount > 0
                case .wishlist: return site.wishlist
                case .planned: return false // TODO planned
                }
            } else {
                switch exploreFilter {
                case .all: return true
                case .nearby: return true // TODO distance
                case .popular: return site.visitedCount > 5
                case .beginner: return site.difficulty.rawValue == "Beginner"
                }
            }
        }
        return filtered
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
        return groups.map { Area(id: $0.key, name: $0.key, country: parseAreaCountry($0.value.first!.location).country, siteCount: $0.value.count) }
            .sorted { $0.name < $1.name }
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
        
        let siteRepo = SiteRepository(database: AppDatabase.shared)
        do {
            let fetchedSites = try siteRepo.fetchAll()
            let regionNames = Set(fetchedSites.map { $0.region })
            let computedRegions = regionNames.map { name in
                let regionSites = fetchedSites.filter { $0.region == name }
                return Region(
                    id: name,
                    name: name,
                    totalSites: regionSites.count,
                    visitedCount: regionSites.filter { $0.visitedCount > 0 }.count
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
    case all, nearby, popular, beginner
}

enum Tier {
    case regions, areas, sites
}

struct Region: Identifiable, Equatable {
    let id: String
    let name: String
    let totalSites: Int
    let visitedCount: Int
}

struct Area: Identifiable, Equatable {
    let id: String
    let name: String
    let country: String
    let siteCount: Int
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

// MARK: - V3 Enums
enum Scope { case saved, discover }
enum EntityTab { case sites, shops }

#Preview {
    NewMapView()
}
