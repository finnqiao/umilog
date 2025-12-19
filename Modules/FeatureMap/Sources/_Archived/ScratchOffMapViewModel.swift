import Foundation
import CoreLocation
import Combine
import UmiDB
import UmiCoreKit

@MainActor
public class ScratchOffMapViewModel: ObservableObject {
    @Published public var diveSites: [DiveSite] = []
    @Published public var visitedCountries: Set<String> = []
    @Published public var currentCountry: Country?
    @Published public var selectedSite: DiveSite?
    @Published public var worldExplorationPercentage: Double = 0
    
    private let database: AppDatabase
    private let diveRepository: DiveRepository
    private let siteRepository: SiteRepository
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
        self.database = AppDatabase.shared
        self.diveRepository = DiveRepository(database: database)
        self.siteRepository = SiteRepository(database: database)
        
        setupBindings()
    }
    
    private func setupBindings() {
        // Subscribe to dive updates to refresh visited countries
        NotificationCenter.default
            .publisher(for: .diveLogUpdated)
            .sink { [weak self] _ in
                Task {
                    await self?.loadData()
                }
            }
            .store(in: &cancellables)
    }
    
    public func loadData() async {
        do {
            // Load all dive sites
            diveSites = try siteRepository.fetchAll()
            
            // Load visited countries from dives
            let dives = try await diveRepository.getAllDives()
            await updateVisitedCountries(from: dives)
            
            // Calculate exploration percentage
            worldExplorationPercentage = calculateExplorationPercentage()
            
        } catch {
            print("Failed to load map data: \(error)")
        }
    }
    
    private func updateVisitedCountries(from dives: [DiveLog]) async {
        visitedCountries.removeAll()
        
        for dive in dives {
            if let site = diveSites.first(where: { $0.id == dive.siteId }),
               let country = Country.countryForCoordinate(site.coordinate) {
                visitedCountries.insert(country.code)
            }
        }
    }
    
    private func calculateExplorationPercentage() -> Double {
        let totalCountries = Double(Country.allCountries.count)
        let visited = Double(visitedCountries.count)
        return (visited / totalCountries) * 100
    }
    
    public func hasVisitedSite(_ site: DiveSite) -> Bool {
        // Check if user has any dives at this site
        do {
            let dives = try diveRepository.getDivesForSiteSync(siteId: site.id)
            return !dives.isEmpty
        } catch {
            return false
        }
    }
    
    public func selectSite(_ site: DiveSite) {
        selectedSite = site
        if let country = Country.countryForCoordinate(site.coordinate) {
            currentCountry = country
        }
    }
    
    public func getCountryStats(for country: Country) -> CountryDiveStats {
        do {
            let allDives = try diveRepository.getAllDivesSync()
            let sitesInCountry = diveSites.filter { site in
                Country.countryForCoordinate(site.coordinate)?.code == country.code
            }
            
            let divesInCountry = allDives.filter { dive in
                sitesInCountry.contains { $0.id == dive.siteId }
            }
            
            let uniqueSites = Set(divesInCountry.map { $0.siteId }).count
            let lastDive = divesInCountry.map { $0.date }.max()
            
            return CountryDiveStats(
                totalDives: divesInCountry.count,
                uniqueSites: uniqueSites,
                lastDiveDate: lastDive
            )
        } catch {
            return CountryDiveStats(totalDives: 0, uniqueSites: 0, lastDiveDate: nil)
        }
    }
}

// MARK: - Supporting Types

public struct Country: Identifiable {
    public let id = UUID()
    public let code: String  // ISO 3166-1 alpha-2
    public let name: String
    public let flag: String  // Emoji flag
    public let bounds: CountryBounds?
    
    // Simplified country list for MVP
    public static let allCountries = [
        Country(code: "TH", name: "Thailand", flag: "🇹🇭", bounds: nil),
        Country(code: "ID", name: "Indonesia", flag: "🇮🇩", bounds: nil),
        Country(code: "PH", name: "Philippines", flag: "🇵🇭", bounds: nil),
        Country(code: "MY", name: "Malaysia", flag: "🇲🇾", bounds: nil),
        Country(code: "MV", name: "Maldives", flag: "🇲🇻", bounds: nil),
        Country(code: "EG", name: "Egypt", flag: "🇪🇬", bounds: nil),
        Country(code: "MX", name: "Mexico", flag: "🇲🇽", bounds: nil),
        Country(code: "AU", name: "Australia", flag: "🇦🇺", bounds: nil),
        Country(code: "JP", name: "Japan", flag: "🇯🇵", bounds: nil),
        Country(code: "US", name: "United States", flag: "🇺🇸", bounds: nil),
        Country(code: "ES", name: "Spain", flag: "🇪🇸", bounds: nil),
        Country(code: "IT", name: "Italy", flag: "🇮🇹", bounds: nil),
        Country(code: "GR", name: "Greece", flag: "🇬🇷", bounds: nil),
        Country(code: "HR", name: "Croatia", flag: "🇭🇷", bounds: nil),
        Country(code: "FR", name: "France", flag: "🇫🇷", bounds: nil),
        Country(code: "TR", name: "Turkey", flag: "🇹🇷", bounds: nil),
        Country(code: "CR", name: "Costa Rica", flag: "🇨🇷", bounds: nil),
        Country(code: "BZ", name: "Belize", flag: "🇧🇿", bounds: nil),
        Country(code: "HN", name: "Honduras", flag: "🇭🇳", bounds: nil),
        Country(code: "BS", name: "Bahamas", flag: "🇧🇸", bounds: nil),
    ]
    
    public static func countryForCoordinate(_ coordinate: CLLocationCoordinate2D) -> Country? {
        // Simplified country detection based on coordinate ranges
        // In production, use reverse geocoding or country boundary data
        
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // Rough approximations for popular diving countries
        switch (lat, lon) {
        case (5...21, 95...106): // Thailand region
            return allCountries.first { $0.code == "TH" }
        case (-11...6, 95...141): // Indonesia region
            return allCountries.first { $0.code == "ID" }
        case (4...21, 116...127): // Philippines region
            return allCountries.first { $0.code == "PH" }
        case (0...8, 98...120): // Malaysia region
            return allCountries.first { $0.code == "MY" }
        case (-1...8, 72...74): // Maldives region
            return allCountries.first { $0.code == "MV" }
        case (22...31, 25...36): // Egypt region
            return allCountries.first { $0.code == "EG" }
        case (14...33, -118...(-86)): // Mexico region
            return allCountries.first { $0.code == "MX" }
        case (-44...(-10), 112...154): // Australia region
            return allCountries.first { $0.code == "AU" }
        case (24...46, 122...146): // Japan region
            return allCountries.first { $0.code == "JP" }
        case (24...49, -125...(-66)): // USA region
            return allCountries.first { $0.code == "US" }
        default:
            return nil
        }
    }
}

public struct CountryBounds {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}

public struct CountryDiveStats {
    public let totalDives: Int
    public let uniqueSites: Int
    public let lastDiveDate: Date?
}

// MARK: - Map Stats View

import SwiftUI

public struct MapStatsView: View {
    @ObservedObject var viewModel: ScratchOffMapViewModel
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Overall stats
                    OverallStatsSection(viewModel: viewModel)
                    
                    Divider()
                    
                    // Countries visited
                    VisitedCountriesSection(viewModel: viewModel)
                    
                    Divider()
                    
                    // Achievement progress
                    AchievementProgressSection(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("Exploration Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct OverallStatsSection: View {
    @ObservedObject var viewModel: ScratchOffMapViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Text("World Exploration")
                .font(.headline)
            
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: viewModel.worldExplorationPercentage / 100)
                    .stroke(Color.oceanBlue, lineWidth: 12)
                    .frame(width: 150, height: 150)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(), value: viewModel.worldExplorationPercentage)
                
                VStack {
                    Text("\(Int(viewModel.worldExplorationPercentage))%")
                        .font(.largeTitle.bold())
                    Text("Explored")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack(spacing: 32) {
                StatItem(
                    value: "\(viewModel.visitedCountries.count)",
                    label: "Countries",
                    icon: "flag.fill"
                )
                
                StatItem(
                    value: "\(viewModel.diveSites.filter { viewModel.hasVisitedSite($0) }.count)",
                    label: "Sites",
                    icon: "mappin.circle.fill"
                )
            }
        }
    }
}

struct StatItem: View {
    let value: String
    let label: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.oceanBlue)
            
            Text(value)
                .font(.title2.bold())
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct VisitedCountriesSection: View {
    @ObservedObject var viewModel: ScratchOffMapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Countries Visited")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
                ForEach(Country.allCountries.filter { viewModel.visitedCountries.contains($0.code) }) { country in
                    CountryBadge(country: country)
                }
            }
        }
    }
}

struct CountryBadge: View {
    let country: Country
    
    var body: some View {
        HStack {
            Text(country.flag)
                .font(.title3)
            Text(country.name)
                .font(.caption)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AchievementProgressSection: View {
    @ObservedObject var viewModel: ScratchOffMapViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Achievements")
                .font(.headline)
            
            VStack(spacing: 12) {
                AchievementProgress(
                    title: "Globe Trotter",
                    current: viewModel.visitedCountries.count,
                    target: 10,
                    icon: "globe.americas.fill"
                )
                
                AchievementProgress(
                    title: "Explorer",
                    current: viewModel.visitedCountries.count,
                    target: 20,
                    icon: "map.fill"
                )
                
                AchievementProgress(
                    title: "World Diver",
                    current: viewModel.visitedCountries.count,
                    target: 50,
                    icon: "star.fill"
                )
            }
        }
    }
}

struct AchievementProgress: View {
    let title: String
    let current: Int
    let target: Int
    let icon: String
    
    var progress: Double {
        min(1.0, Double(current) / Double(target))
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(progress >= 1.0 ? .yellow : .gray)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                
                HStack {
                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .yellow : .oceanBlue)
                    
                    Text("\(current)/\(target)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let diveLogUpdated = Notification.Name("diveLogUpdated")
}