import SwiftUI
import UmiDB
import GRDB
import UmiCoreKit
import os

public struct WildlifeView: View {
    @StateObject private var viewModel = WildlifeViewModel()
    @State private var searchText = ""
    @State private var scope: WildlifeScope = .allTime

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Scope chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ScopeChip(title: "All-time", isSelected: scope == .allTime) {
                        scope = .allTime
                        viewModel.updateScope(.allTime, areaBounds: nil)
                    }
                    .accessibilityLabel("All-time sightings")
                    .accessibilityHint("Shows species from all your dives")
                    .accessibilityAddTraits(scope == .allTime ? .isSelected : [])

                    ScopeChip(title: "This area", isSelected: scope == .thisArea) {
                        scope = .thisArea
                        viewModel.updateScope(.thisArea, areaBounds: viewModel.currentAreaBounds)
                    }
                    .accessibilityLabel("This area sightings")
                    .accessibilityHint("Shows species from dive sites in the current map area")
                    .accessibilityAddTraits(scope == .thisArea ? .isSelected : [])
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            .onReceive(NotificationCenter.default.publisher(for: .mapViewportChanged)) { notification in
                if let bounds = notification.userInfo?["bounds"] as? MapBounds {
                    viewModel.currentAreaBounds = bounds
                    if scope == .thisArea {
                        viewModel.updateScope(.thisArea, areaBounds: bounds)
                    }
                }
            }
            
            // Species grid
            ScrollView {
                if viewModel.filteredSpecies.isEmpty {
                    ContentUnavailableView {
                        Label(searchText.isEmpty ? "No Wildlife Logged" : "No Results", systemImage: "fish")
                    } description: {
                        Text(searchText.isEmpty
                            ? "Log sightings during your dives to build your wildlife catalog."
                            : "No species match '\(searchText)'")
                    } actions: {
                        if searchText.isEmpty {
                            Button {
                                NotificationCenter.default.post(name: .startLiveLogRequested, object: nil)
                            } label: {
                                Label("Log a Dive", systemImage: "plus")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.filteredSpecies) { species in
                            NavigationLink(destination: SpeciesDetailView(species: species)) {
                                SpeciesCard(
                                    speciesId: species.id,
                                    name: species.name,
                                    scientificName: species.scientificName,
                                    category: species.category,
                                    seen: viewModel.sightingCounts[species.id] ?? 0 > 0,
                                    sightingCount: viewModel.sightingCounts[species.id] ?? 0
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
            .onChange(of: searchText) { newValue in
                viewModel.search(newValue)
            }
        }
        .navigationTitle("Wildlife")
        .searchable(text: $searchText, prompt: "Search species...")
        .underwaterAccent()
    }
}

struct ScopeChip: View {
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

struct SpeciesCard: View {
    let speciesId: String
    let name: String
    let scientificName: String
    let category: WildlifeSpecies.Category
    let seen: Bool
    let sightingCount: Int

    @ScaledMetric(relativeTo: .body) private var imageSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            SpeciesImage(
                speciesId: speciesId,
                category: category,
                size: imageSize,
                seen: seen
            )

            Text(name)
                .font(SwiftUI.Font.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(scientificName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .italic()
                .lineLimit(1)

            if seen {
                Text("Seen \(sightingCount)x")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var categoryColor: Color {
        switch category {
        case .fish:
            return .blue
        case .coral:
            return .orange
        case .mammal:
            return .purple
        case .invertebrate:
            return .pink
        case .reptile:
            return .green
        }
    }
}

@MainActor
class WildlifeViewModel: ObservableObject {
    @Published var allSpecies: [WildlifeSpecies] = []
    @Published var filteredSpecies: [WildlifeSpecies] = []
    @Published var sightingCounts: [String: Int] = [:]

    /// Current map area bounds for "This area" filtering
    var currentAreaBounds: MapBounds?

    private var currentScope: WildlifeScope = .allTime
    private let speciesRepository = SpeciesRepository(database: AppDatabase.shared)
    private let database = AppDatabase.shared

    init() {
        loadSpecies()
    }

    /// Update the scope and reload sighting counts accordingly
    func updateScope(_ scope: WildlifeScope, areaBounds: MapBounds?) {
        currentScope = scope
        currentAreaBounds = areaBounds
        loadSightingCounts()
    }

    func loadSpecies() {
        Task {
            do {
                let species = try speciesRepository.fetchAll()
                await updateSpecies(species)
                await loadSightingCounts()
            } catch {
                Log.wildlife.error("Error loading species: \(error.localizedDescription)")
            }
        }
    }

    func search(_ query: String) {
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            filteredSpecies = allSpecies
        } else {
            Task {
                do {
                    let results = try speciesRepository.search(query)
                    await MainActor.run {
                        self.filteredSpecies = results
                    }
                } catch {
                    Log.wildlife.error("Error searching species: \(error.localizedDescription)")
                    await MainActor.run {
                        self.filteredSpecies = []
                    }
                }
            }
        }
    }

    @MainActor
    private func updateSpecies(_ species: [WildlifeSpecies]) {
        self.allSpecies = species
        self.filteredSpecies = species
    }

    @MainActor
    private func loadSightingCounts() {
        Task {
            do {
                let counts: [String: Int]

                if currentScope == .thisArea, let bounds = currentAreaBounds {
                    // Filter sightings to only those from dives at sites within bounds
                    counts = try database.read { db in
                        var result: [String: Int] = [:]
                        let sql = """
                            SELECT s.speciesId, COUNT(*) as count
                            FROM sightings s
                            INNER JOIN dive_logs d ON s.diveId = d.id
                            INNER JOIN dive_sites ds ON d.siteId = ds.id
                            WHERE ds.latitude BETWEEN ? AND ?
                            AND ds.longitude BETWEEN ? AND ?
                            GROUP BY s.speciesId
                            """
                        let rows = try Row.fetchAll(
                            db,
                            sql: sql,
                            arguments: [bounds.minLatitude, bounds.maxLatitude, bounds.minLongitude, bounds.maxLongitude]
                        )
                        for row in rows {
                            if let speciesId = row["speciesId"] as? String,
                               let count = row["count"] as? Int {
                                result[speciesId] = count
                            }
                        }
                        return result
                    }
                    // Filter species list to only those with sightings in this area
                    self.filteredSpecies = self.allSpecies.filter { counts[$0.id] ?? 0 > 0 }
                } else {
                    // All-time: no geographic filter
                    counts = try database.read { db in
                        var result: [String: Int] = [:]
                        let rows = try Row.fetchAll(
                            db,
                            sql: "SELECT speciesId, COUNT(*) as count FROM sightings GROUP BY speciesId"
                        )
                        for row in rows {
                            if let speciesId = row["speciesId"] as? String,
                               let count = row["count"] as? Int {
                                result[speciesId] = count
                            }
                        }
                        return result
                    }
                    self.filteredSpecies = self.allSpecies
                }

                self.sightingCounts = counts
            } catch {
                Log.wildlife.error("Error loading sighting counts: \(error.localizedDescription)")
            }
        }
    }
}

enum WildlifeScope {
    case allTime, thisArea
}

// MARK: - Notifications

extension Notification.Name {
    /// Posted when the map viewport changes, with "bounds" (MapBounds) in userInfo
    /// Namespaced to prevent cross-app notification conflicts
    static let mapViewportChanged = Notification.Name("app.umilog.mapViewportChanged")
}
