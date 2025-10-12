import SwiftUI
import MapKit
import UmiDB
import FeatureLiveLog
import UmiDesignSystem

public struct NewMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 27.7833, longitude: 34.3167),
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
    )
    @State private var selectedSite: DiveSite?
    @State private var showingSiteDetail = false
    @State private var showSearch = false
    @State private var showFilters = false
    @State private var searchText = ""
    
    public init() {}
    
    private var primaryColor: Color { viewModel.mode == .explore ? .purple : .oceanBlue }
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Map layer (clustered, POIs suppressed)
            MapClusterView(
                annotations: viewModel.visibleSites.map { s in
                    SiteAnnotation(
                        id: s.id,
                        coordinate: CLLocationCoordinate2D(latitude: s.latitude, longitude: s.longitude),
                        title: s.name,
                        subtitle: s.location,
                        visited: s.visitedCount > 0,
                        wishlist: s.wishlist)
                },
                onSelect: { siteId in
                    if let s = viewModel.sites.first(where: { $0.id == siteId }) {
                        selectedSite = s
                        showingSiteDetail = true
                    }
                },
                onRegionChange: { region in
                    Task { await viewModel.refreshVisibleSites(in: region) }
                },
                center: mapRegion.center
            )
            .ignoresSafeArea()
            
            // Top controls: only Mode segmented control at top
            VStack(spacing: 0) {
                HStack {
                    Picker("Mode", selection: $viewModel.mode) {
                        Text("My Map").tag(MapMode.myMap)
                        Text("Explore").tag(MapMode.explore)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: viewModel.mode) { _ in
                        Haptics.soft()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                Spacer()

                // Bottom contextual sheet
                VStack(spacing: 12) {
                    // Breadcrumb header + counts
                    BreadcrumbHeader(viewModel: viewModel)
                        .padding(.top, 8)
                        .padding(.horizontal, 16)

                    // Filter chips inside sheet (contextual)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            if viewModel.mode == .myMap {
                                FilterChip(title: "Visited (\(viewModel.visitedCount))", isSelected: viewModel.statusFilter == .visited, action: {
                                    withAnimation(.spring(response: 0.25)) {
                                        viewModel.statusFilter = .visited
                                        viewModel.tier = .sites
                                        viewModel.selectedRegion = nil
                                        viewModel.selectedArea = nil
                                    }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                FilterChip(title: "Wishlist (\(viewModel.wishlistCount))", isSelected: viewModel.statusFilter == .wishlist, action: {
                                    withAnimation(.spring(response: 0.25)) {
                                        viewModel.statusFilter = .wishlist
                                        viewModel.tier = .sites
                                        viewModel.selectedRegion = nil
                                        viewModel.selectedArea = nil
                                    }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                FilterChip(title: "Planned (\(viewModel.plannedCount))", isSelected: viewModel.statusFilter == .planned, action: {
                                    withAnimation(.spring(response: 0.25)) {
                                        viewModel.statusFilter = .planned
                                        viewModel.tier = .sites
                                        viewModel.selectedRegion = nil
                                        viewModel.selectedArea = nil
                                    }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                            } else {
                                FilterChip(title: "All", isSelected: viewModel.exploreFilter == .all, action: {
                                    withAnimation(.spring(response: 0.25)) { viewModel.exploreFilter = .all; viewModel.tier = .sites; viewModel.selectedRegion = nil; viewModel.selectedArea = nil }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                FilterChip(title: "Nearby", isSelected: viewModel.exploreFilter == .nearby, action: {
                                    withAnimation(.spring(response: 0.25)) { viewModel.exploreFilter = .nearby; viewModel.tier = .sites; viewModel.selectedRegion = nil; viewModel.selectedArea = nil }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                FilterChip(title: "Popular", isSelected: viewModel.exploreFilter == .popular, action: {
                                    withAnimation(.spring(response: 0.25)) { viewModel.exploreFilter = .popular; viewModel.tier = .sites; viewModel.selectedRegion = nil; viewModel.selectedArea = nil }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                FilterChip(title: "Beginner", isSelected: viewModel.exploreFilter == .beginner, action: {
                                    withAnimation(.spring(response: 0.25)) { viewModel.exploreFilter = .beginner; viewModel.tier = .sites; viewModel.selectedRegion = nil; viewModel.selectedArea = nil }
                                    Haptics.tap()
                                }, primaryColor: primaryColor)
                                // Additional chips (stubs)
                                FilterChip(title: "Wrecks", isSelected: false, action: {}, primaryColor: primaryColor)
                                FilterChip(title: "Cave", isSelected: false, action: {}, primaryColor: primaryColor)
                                FilterChip(title: "Nitrox", isSelected: false, action: {}, primaryColor: primaryColor)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 4)

                    // Contextual list based on tier
                    Group {
                        switch viewModel.tier {
                        case .regions:
                            RegionsListView(
                                regions: viewModel.regions,
                                selectedRegion: $viewModel.selectedRegion,
                                onRegionTap: { region in
                                    withAnimation(.spring(response: 0.25)) {
                                        viewModel.selectedRegion = region
                                        viewModel.selectedArea = nil
                                        viewModel.tier = .areas
                                    }
                                    Haptics.tap()
                                }
                            )
                            .frame(maxHeight: 260)
                        case .areas:
                            AreasListView(areas: viewModel.areasInSelectedRegion, onAreaTap: { area in
                                withAnimation(.spring(response: 0.25)) {
                                    viewModel.selectedArea = area
                                    viewModel.tier = .sites
                                }
                                Haptics.tap()
                            })
                                .frame(maxHeight: 260)
                        case .sites:
                            SitesListView(sites: viewModel.filteredSites, onSiteTap: { site in
                                Haptics.soft()
                                selectedSite = site
                                showingSiteDetail = true
                            })
                            .frame(maxHeight: 260)
                        }
                    }
                }
                .background(.ultraThinMaterial)
                .cornerRadius(20, corners: [.topLeft, .topRight])
            }
        }
        .tint(primaryColor)
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { Button(action: { showSearch = true; Haptics.soft() }) { Image(systemName: "magnifyingglass") } }
            ToolbarItem(placement: .topBarTrailing) { Button(action: { showFilters = true; Haptics.soft() }) { Image(systemName: "line.3.horizontal.decrease.circle") } }
        }
        .sheet(isPresented: $showingSiteDetail) {
            if let site = selectedSite {
                SiteDetailSheet(site: site, mode: viewModel.mode)
            }
        }
        .sheet(isPresented: $showSearch) {
            SearchSheet(searchText: $searchText, sites: viewModel.sites) { site in
                selectedSite = site
                showingSiteDetail = true
                showSearch = false
            }
        }
        .sheet(isPresented: $showFilters) {
            FilterSheet(mode: $viewModel.mode, statusFilter: $viewModel.statusFilter, exploreFilter: $viewModel.exploreFilter, onDismiss: { showFilters = false })
                .presentationDetents([.medium])
        }
        .task {
            await viewModel.loadSites()
        }
        .accessibilityElement(children: .contain)
        .accessibilitySortPriority(1)
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
        }
        .buttonStyle(.bordered)
        .tint(isSelected ? primaryColor : Color.gray.opacity(0.4))
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
                    .foregroundStyle(viewModel.tier == .regions ? Color.oceanBlue : SwiftUI.Color(UIColor.label))
                    .onTapGesture { viewModel.tier = .regions }
                Text("›").foregroundStyle(.secondary)
                Text(viewModel.selectedRegion?.name ?? "Areas")
                    .foregroundStyle(viewModel.tier == .areas ? Color.oceanBlue : SwiftUI.Color(UIColor.secondaryLabel))
                    .onTapGesture { if viewModel.selectedRegion != nil { viewModel.tier = .areas } }
                Text("›").foregroundStyle(.secondary)
                Text("Sites")
                    .foregroundStyle(viewModel.tier == .sites ? Color.oceanBlue : SwiftUI.Color(UIColor.secondaryLabel))
            }
            Spacer()
            // Counts
            Text(countText)
                .font(SwiftUI.Font.system(.caption, design: .default))
                .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
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
            
            VStack(alignment: .leading, spacing: 2) {
                Text(region.name)
                    .font(.body)
                Text("\(region.visitedCount)/\(region.totalSites) visited")
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
            }
            
            Spacer()
            
            if region.visitedCount > 0 {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(site.visitedCount > 0 ? Color.oceanBlue : (site.wishlist ? Color.yellow : Color.gray.opacity(0.3)))
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(site.location)
                    .font(.caption)
                    .foregroundStyle(SwiftUI.Color(UIColor.secondaryLabel))
                
                // Quick facts chips
                HStack(spacing: 6) {
                    QuickFactChip(text: site.difficulty.rawValue)
                    QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                    QuickFactChip(text: "\(Int(site.averageTemp))°C")
                }
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
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
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

@MainActor
class MapViewModel: ObservableObject {
    @Published var mode: MapMode = .myMap
    @Published var statusFilter: StatusFilter = .visited
    @Published var exploreFilter: ExploreFilter = .all
    @Published var tier: Tier = .regions
    @Published var selectedRegion: Region?
    @Published var selectedArea: Area?
    
    @Published var sites: [DiveSite] = []
    @Published var regions: [Region] = []
    @Published var loading: Bool = false
    @Published var visibleSites: [DiveSite] = []
    
    var filteredSites: [DiveSite] {
        visibleSites.filter { site in
            // Region filter
            if let region = selectedRegion, site.region != region.name { return false }
            // Area filter
            if let area = selectedArea, parseAreaCountry(site.location).area != area.name { return false }
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

    func loadSites() async {
        loading = true
        defer { loading = false }
        let siteRepo = SiteRepository(database: AppDatabase.shared)
        do {
            sites = try siteRepo.fetchAll()
            let regionNames = Set(sites.map { $0.region })
            regions = regionNames.map { name in
                let regionSites = sites.filter { $0.region == name }
                return Region(
                    id: name,
                    name: name,
                    totalSites: regionSites.count,
                    visitedCount: regionSites.filter { $0.visitedCount > 0 }.count
                )
            }.sorted { $0.name < $1.name }
        } catch {
            print("Failed to load sites: \(error)")
        }
    }
    
    func refreshVisibleSites(in region: MKCoordinateRegion) async {
        // Compute bounding box
        let span = region.span
        let center = region.center
        let minLat = center.latitude - span.latitudeDelta/2
        let maxLat = center.latitude + span.latitudeDelta/2
        let minLon = center.longitude - span.longitudeDelta/2
        let maxLon = center.longitude + span.longitudeDelta/2
        let repo = SiteRepository(database: AppDatabase.shared)
        do {
            let boxSites = try repo.fetchInBounds(minLat: minLat, maxLat: maxLat, minLon: minLon, maxLon: maxLon)
            await MainActor.run { self.visibleSites = boxSites }
        } catch {
            print("Failed to fetch box sites: \(error)")
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

struct Region: Identifiable {
    let id: String
    let name: String
    let totalSites: Int
    let visitedCount: Int
}

struct Area: Identifiable {
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
                    .onChange(of: mode) { _ in Haptics.soft() }
                }
                
                if mode == .myMap {
                    Section("Status Filter") {
                        Picker("Status", selection: $statusFilter) {
                            Text("Visited").tag(StatusFilter.visited)
                            Text("Wishlist").tag(StatusFilter.wishlist)
                            Text("Planned").tag(StatusFilter.planned)
                        }.pickerStyle(.segmented)
                        .onChange(of: statusFilter) { _ in Haptics.tap() }
                    }
                } else {
                    Section("Explore Filter") {
                        Picker("Explore", selection: $exploreFilter) {
                            Text("All").tag(ExploreFilter.all)
                            Text("Nearby").tag(ExploreFilter.nearby)
                            Text("Popular").tag(ExploreFilter.popular)
                            Text("Beginner").tag(ExploreFilter.beginner)
                        }.pickerStyle(.segmented)
                        .onChange(of: exploreFilter) { _ in Haptics.tap() }
                    }
                }
            }
            .navigationTitle("Filters")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { onDismiss(); dismiss() } } }
        }
    }
}

#Preview {
    NewMapView()
}
