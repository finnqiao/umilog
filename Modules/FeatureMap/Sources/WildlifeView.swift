import SwiftUI
import UmiDB
import GRDB

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
                    }
                    ScopeChip(title: "This area", isSelected: scope == .thisArea) {
                        scope = .thisArea
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            
            // Species grid
            ScrollView {
                if viewModel.filteredSpecies.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "fish")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No species found")
                            .font(.headline)
                        Text(searchText.isEmpty ? "Start logging dives to see wildlife" : "No matches for '\(searchText)'")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                        ForEach(viewModel.filteredSpecies) { species in
                            SpeciesCard(
                                name: species.name,
                                scientificName: species.scientificName,
                                seen: viewModel.sightingCounts[species.id] ?? 0 > 0,
                                sightingCount: viewModel.sightingCounts[species.id] ?? 0
                            )
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
                .background(isSelected ? Color.purple : Color.gray.opacity(0.15))
                .foregroundStyle(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct SpeciesCard: View {
    let name: String
    let scientificName: String
    let seen: Bool
    let sightingCount: Int
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(seen ? Color.purple.opacity(0.2) : Color.gray.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: "fish.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(seen ? .purple : .gray)
            }
            
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
                    .background(Color.purple.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

@MainActor
class WildlifeViewModel: ObservableObject {
    @Published var allSpecies: [WildlifeSpecies] = []
    @Published var filteredSpecies: [WildlifeSpecies] = []
    @Published var sightingCounts: [String: Int] = [:]
    
    private let speciesRepository = SpeciesRepository(database: AppDatabase.shared)
    private let database = AppDatabase.shared
    
    init() {
        loadSpecies()
    }
    
    func loadSpecies() {
        Task {
            do {
                let species = try speciesRepository.fetchAll()
                await updateSpecies(species)
                await loadSightingCounts()
            } catch {
                print("Error loading species: \(error)")
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
                    print("Error searching species: \(error)")
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
                let counts = try database.read { db in
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
                await MainActor.run {
                    self.sightingCounts = counts
                }
            } catch {
                print("Error loading sighting counts: \(error)")
            }
        }
    }
}

enum WildlifeScope {
    case allTime, thisArea
}
