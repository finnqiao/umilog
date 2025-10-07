import SwiftUI
import MapKit
import UmiDesignSystem
import UmiDB

public struct ScratchOffMapView: View {
    @StateObject private var viewModel = ScratchOffMapViewModel()
    @State private var mapRegion = MKMapRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    )
    @State private var showingStats = false
    @State private var selectedCountry: Country?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Base map layer
            Map(coordinateRegion: $mapRegion, 
                interactionModes: .all,
                showsUserLocation: true,
                userTrackingMode: .none,
                annotationItems: viewModel.diveSites) { site in
                MapAnnotation(coordinate: site.coordinate) {
                    DiveSiteAnnotation(site: site, isVisited: viewModel.hasVisitedSite(site))
                        .onTapGesture {
                            viewModel.selectSite(site)
                        }
                }
            }
            .ignoresSafeArea()
            .overlay(alignment: .top) {
                // Scratch-off overlay for unvisited countries
                ScratchOffOverlay(
                    visitedCountries: viewModel.visitedCountries,
                    onCountryTapped: { country in
                        selectedCountry = country
                    }
                )
                .allowsHitTesting(false)
            }
            
            // Stats overlay button
            VStack {
                HStack {
                    Spacer()
                    
                    Button(action: { showingStats.toggle() }) {
                        StatsButton(
                            countriesVisited: viewModel.visitedCountries.count,
                            percentageExplored: viewModel.worldExplorationPercentage
                        )
                    }
                    .padding()
                }
                
                Spacer()
            }
            
            // Bottom info card
            if let country = selectedCountry ?? viewModel.currentCountry {
                VStack {
                    Spacer()
                    
                    CountryInfoCard(
                        country: country,
                        stats: viewModel.getCountryStats(for: country)
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingStats) {
            MapStatsView(viewModel: viewModel)
        }
        .task {
            await viewModel.loadData()
        }
    }
}

// MARK: - Components

struct DiveSiteAnnotation: View {
    let site: DiveSite
    let isVisited: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isVisited ? Color.oceanBlue : Color.gray.opacity(0.5))
                .frame(width: 20, height: 20)
            
            Image(systemName: isVisited ? "water.waves" : "mappin")
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

struct StatsButton: View {
    let countriesVisited: Int
    let percentageExplored: Double
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(countriesVisited) countries")
                        .font(.caption.bold())
                    Text("\(Int(percentageExplored))% explored")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .cornerRadius(16)
        }
    }
}

struct CountryInfoCard: View {
    let country: Country
    let stats: CountryDiveStats
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(country.flag)
                    .font(.largeTitle)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                        .font(.headline)
                    
                    if stats.totalDives > 0 {
                        Text("\(stats.totalDives) dives • \(stats.uniqueSites) sites")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Not visited yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if stats.totalDives > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.seaGreen)
                        .font(.title2)
                }
            }
            
            if let lastDive = stats.lastDiveDate {
                Text("Last dive: \(lastDive, style: .date)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Scratch-off Overlay

struct ScratchOffOverlay: View {
    let visitedCountries: Set<String>
    let onCountryTapped: (Country) -> Void
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(Country.allCountries) { country in
                if !visitedCountries.contains(country.code) {
                    // Draw scratch-off effect for unvisited countries
                    ScratchPattern()
                        .mask(
                            CountryShape(country: country)
                        )
                        .opacity(0.7)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

struct ScratchPattern: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.gray.opacity(0.8),
                    Color.gray.opacity(0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Scratchy texture overlay
            Image(systemName: "cloud.fill")
                .resizable()
                .foregroundColor(.white.opacity(0.1))
                .blendMode(.overlay)
        }
    }
}

// Placeholder for actual country shape rendering
struct CountryShape: View {
    let country: Country
    
    var body: some View {
        // In production, this would use actual country boundary data
        Rectangle()
            .fill(Color.clear)
    }
}

// MARK: - Preview

#Preview {
    ScratchOffMapView()
}