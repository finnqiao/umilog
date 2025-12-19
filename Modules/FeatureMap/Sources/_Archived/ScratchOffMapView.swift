import SwiftUI
import MapKit
import UmiDesignSystem
import UmiDB
import FeatureLiveLog

public struct ScratchOffMapView: View {
    @StateObject private var viewModel = ScratchOffMapViewModel()
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 20, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 120, longitudeDelta: 120)
    )
    @State private var showingStats = false
    @State private var selectedCountry: Country?
    @State private var showingQuickLog = false
    @State private var showingWizard = false
    @State private var showingLogOptions = false
    
    public init() {}
    
    public var body: some View {
        ZStack {
            // Base map layer
            Map(coordinateRegion: $mapRegion,
                interactionModes: .all,
                showsUserLocation: true,
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
                    .padding(.horizontal)
                    
                    // Floating action bar with Quick Log
                    FloatingActionBar {
                        showingLogOptions = true
                    }
                    .padding(.bottom, 16)
                }
            } else {
                // Show FAB even without selected country
                VStack {
                    Spacer()
                    FloatingActionBar {
                        showingLogOptions = true
                    }
                    .padding(.bottom, 16)
                }
            }
        }
        .sheet(isPresented: $showingStats) {
            MapStatsView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingQuickLog) {
            QuickLogView(suggestedSite: viewModel.selectedSite)
        }
        .sheet(isPresented: $showingWizard) {
            LiveLogWizardView(initialSite: viewModel.selectedSite)
        }
        .confirmationDialog("Log dive", isPresented: $showingLogOptions, titleVisibility: .visible) {
            Button("Full log (4 steps)") { showingWizard = true }
            Button("Quick log") { showingQuickLog = true }
            Button("Cancel", role: .cancel) {}
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
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(countriesVisited) countries")
                        .bold()
                        .foregroundStyle(.primary)
                    Text("\(Int(percentageExplored))% explored")
                        .foregroundStyle(.secondary)
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
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(country.name)
                    
                    if stats.totalDives > 0 {
                        Text("\(stats.totalDives) dives • \(stats.uniqueSites) sites")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Not visited yet")
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if stats.totalDives > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.seaGreen)
                }
            }
            
            if let lastDive = stats.lastDiveDate {
                Text("Last dive: \(lastDive, style: .date)")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
}

// MARK: - Floating Action Bar

struct FloatingActionBar: View {
    let onLog: () -> Void
    var body: some View {
        HStack(spacing: 24) {
            // Map tab indicator (selected)
            VStack {
                Image(systemName: "map.fill")
                Text("Map").font(.caption2)
            }
            .padding(12)
            .background(Color.white.opacity(0.8))
            .cornerRadius(20)
            
            Spacer(minLength: 0)
            
            Button(action: onLog) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 36, weight: .bold))
            }
            .tint(Color.oceanBlue)
            
            Spacer(minLength: 0)
            
            // Placeholder slots for bottom items
            HStack(spacing: 24) {
                VStack { Image(systemName: "clock"); Text("History").font(.caption2) }
                    .opacity(0.6)
                VStack { Image(systemName: "fish"); Text("Wildlife").font(.caption2) }
                    .opacity(0.6)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .cornerRadius(28)
        .padding(.horizontal)
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