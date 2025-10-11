import SwiftUI
import MapKit
import UmiDB
import FeatureLiveLog

public struct NewMapView: View {
    @StateObject private var viewModel = MapViewModel()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 27.7833, longitude: 34.3167),
        span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
    )
    @State private var selectedSite: DiveSite?
    @State private var showingSiteDetail = false
    
    public init() {}
    
    public var body: some View {
        ZStack(alignment: .bottom) {
            // Map layer
            Map(coordinateRegion: $mapRegion,
                interactionModes: .all,
                showsUserLocation: true,
                annotationItems: viewModel.visibleSites) { site in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: site.latitude, longitude: site.longitude)) {
                    PinView(site: site, isSelected: selectedSite?.id == site.id)
                        .onTapGesture {
                            selectedSite = site
                            showingSiteDetail = true
                        }
                }
            }
            .ignoresSafeArea()
            
            // Top controls overlay
            VStack(spacing: 0) {
                // Mode segmented control
                Picker("Mode", selection: $viewModel.mode) {
                    Text("My Map").tag(MapMode.myMap)
                    Text("Explore").tag(MapMode.explore)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                
                // Filter chips row
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if viewModel.mode == .myMap {
                            FilterChip(title: "Visited (\(viewModel.visitedCount))", isSelected: viewModel.statusFilter == .visited) {
                                viewModel.statusFilter = .visited
                            }
                            FilterChip(title: "Wishlist (\(viewModel.wishlistCount))", isSelected: viewModel.statusFilter == .wishlist) {
                                viewModel.statusFilter = .wishlist
                            }
                            FilterChip(title: "Planned (\(viewModel.plannedCount))", isSelected: viewModel.statusFilter == .planned) {
                                viewModel.statusFilter = .planned
                            }
                        } else {
                            FilterChip(title: "All", isSelected: viewModel.exploreFilter == .all) {
                                viewModel.exploreFilter = .all
                            }
                            FilterChip(title: "Nearby", isSelected: viewModel.exploreFilter == .nearby) {
                                viewModel.exploreFilter = .nearby
                            }
                            FilterChip(title: "Popular", isSelected: viewModel.exploreFilter == .popular) {
                                viewModel.exploreFilter = .popular
                            }
                            FilterChip(title: "Beginner", isSelected: viewModel.exploreFilter == .beginner) {
                                viewModel.exploreFilter = .beginner
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                
                // Tier tabs
                HStack(spacing: 0) {
                    TierTab(title: "Regions", isSelected: viewModel.tier == .regions) {
                        viewModel.tier = .regions
                    }
                    TierTab(title: "Areas", isSelected: viewModel.tier == .areas) {
                        viewModel.tier = .areas
                    }
                    TierTab(title: "Sites", isSelected: viewModel.tier == .sites) {
                        viewModel.tier = .sites
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
                
                Spacer()
                
                // Bottom sheet list
                if viewModel.tier == .regions {
                    RegionsListView(regions: viewModel.regions, selectedRegion: $viewModel.selectedRegion)
                        .frame(height: 200)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20, corners: [.topLeft, .topRight])
                } else if viewModel.tier == .sites {
                    SitesListView(sites: viewModel.visibleSites, onSiteTap: { site in
                        selectedSite = site
                        showingSiteDetail = true
                    })
                    .frame(height: 200)
                    .background(.ultraThinMaterial)
                    .cornerRadius(20, corners: [.topLeft, .topRight])
                }
            }
        }
        .navigationTitle(viewModel.mode == .myMap ? "My Map" : "Explore")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingSiteDetail) {
            if let site = selectedSite {
                SiteDetailSheet(site: site, mode: viewModel.mode)
            }
        }
        .task {
            await viewModel.loadSites()
        }
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
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(SwiftUI.Font.subheadline)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.oceanBlue : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

// MARK: - Tier Tabs

struct TierTab: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(SwiftUI.Font.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.oceanBlue : .secondary)
                
                if isSelected {
                    Capsule()
                        .fill(Color.oceanBlue)
                        .frame(height: 3)
                } else {
                    Spacer().frame(height: 3)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Regions List

struct RegionsListView: View {
    let regions: [Region]
    @Binding var selectedRegion: Region?
    
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
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                ForEach(regions) { region in
                    RegionRow(region: region)
                        .onTapGesture {
                            selectedRegion = region
                        }
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
                    .foregroundStyle(.secondary)
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
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sites) { site in
                    SiteRow(site: site)
                        .onTapGesture {
                            onSiteTap(site)
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
                    .foregroundStyle(.secondary)
                
                // Quick facts chips
                HStack(spacing: 6) {
                    QuickFactChip(text: site.difficulty.rawValue)
                    QuickFactChip(text: "Max \(Int(site.maxDepth))m")
                    QuickFactChip(text: "\(Int(site.averageTemp))°C")
                }
            }
            
            Spacer()
            
            Button(action: {}) {
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
    
    @Published var sites: [DiveSite] = []
    @Published var regions: [Region] = []
    
    var visibleSites: [DiveSite] {
        sites.filter { site in
            if mode == .myMap {
                switch statusFilter {
                case .visited: return site.visitedCount > 0
                case .wishlist: return site.wishlist
                case .planned: return false  // TODO: Add planned logic
                }
            } else {
                switch exploreFilter {
                case .all: return true
                case .nearby: return true  // TODO: Add distance logic
                case .popular: return site.visitedCount > 5  // Placeholder
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
    
    func loadSites() async {
        // Load from seed data
        let siteRepo = SiteRepository(database: AppDatabase.shared)
        do {
            sites = try siteRepo.fetchAll()
            
            // Create regions from sites
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

#Preview {
    NewMapView()
}
