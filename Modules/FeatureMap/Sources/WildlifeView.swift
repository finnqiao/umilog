import SwiftUI
import UmiDB
import GRDB
import UmiCoreKit
import UmiDesignSystem
import os

public struct WildlifeView: View {
    @StateObject private var viewModel = WildlifeViewModel()
    @State private var searchText = ""
    @State private var scope: WildlifeScope = .allTime
    @State private var browseMode: WildlifeBrowseMode = .categories
    @State private var selectedCategory: WildlifeSpecies.Category?
    @State private var selectedFamily: SpeciesFamily?

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            scopeChips
            browseChips

            ScrollView {
                content
            }
            .onChange(of: searchText) {
                viewModel.search(searchText)
                if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, browseMode == .all {
                    viewModel.loadAllSpeciesIfNeeded()
                }
            }
        }
        .navigationTitle("Wildlife")
        .searchable(text: $searchText, prompt: "Search species...")
        .underwaterAccent()
        .background(Color.abyss.ignoresSafeArea())
        .onChange(of: browseMode) { _, newValue in
            selectedCategory = nil
            selectedFamily = nil
            if newValue == .all {
                viewModel.loadAllSpeciesIfNeeded()
            }
        }
        .onChange(of: selectedCategory) { _, newValue in
            guard let category = newValue else { return }
            selectedFamily = nil
            viewModel.loadSpecies(for: category)
        }
        .onChange(of: selectedFamily) { _, newValue in
            guard let family = newValue else { return }
            selectedCategory = nil
            viewModel.loadSpecies(for: family)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mapViewportChanged)) { notification in
            if let bounds = notification.userInfo?["bounds"] as? MapBounds {
                viewModel.currentAreaBounds = bounds
                if scope == .thisArea {
                    viewModel.updateScope(.thisArea, areaBounds: bounds)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .seedDataDidRefresh)) { _ in
            viewModel.loadBrowseData()
            if browseMode == .all {
                viewModel.loadAllSpeciesIfNeeded(force: true)
            }
            if let category = selectedCategory {
                viewModel.loadSpecies(for: category, force: true)
            }
            if let family = selectedFamily {
                viewModel.loadSpecies(for: family, force: true)
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var scopeChips: some View {
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
        .background(Color.trench)
    }

    private var browseChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WildlifeBrowseMode.allCases, id: \.self) { mode in
                    ScopeChip(title: mode.title, isSelected: browseMode == mode) {
                        browseMode = mode
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.abyss)
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 16) {
            if isSearching {
                speciesContent
            } else {
                switch browseMode {
                case .categories:
                    if let category = selectedCategory {
                        SelectionHeader(
                            title: category.rawValue,
                            subtitle: "\(viewModel.filteredSpecies.count) species"
                        ) {
                            selectedCategory = nil
                        }
                        speciesContent
                    } else {
                        categoriesContent
                    }
                case .families:
                    if let family = selectedFamily {
                        SelectionHeader(
                            title: family.name,
                            subtitle: family.scientificName
                        ) {
                            selectedFamily = nil
                        }
                        speciesContent
                    } else {
                        familiesContent
                    }
                case .all:
                    speciesContent
                }
            }
        }
        .padding(.bottom, 16)
    }

    private var speciesContent: some View {
        Group {
            if viewModel.isLoadingSpecies {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading species...")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if viewModel.filteredSpecies.isEmpty {
                ContentUnavailableView {
                    Label(isSearching ? "No Results" : "No Species Found", systemImage: "fish")
                } description: {
                    Text(isSearching
                        ? "No species match '\(searchText)'"
                        : "Try another category or switch the scope.")
                } actions: {
                    if !isSearching && browseMode != .all {
                        Button {
                            browseMode = .all
                            viewModel.loadAllSpeciesIfNeeded()
                        } label: {
                            Label("Browse All Species", systemImage: "sparkles")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.filteredSpecies) { species in
                        let sightingCount = viewModel.sightingCounts[species.id] ?? 0
                        let seen = sightingCount > 0
                        NavigationLink(destination: SpeciesDetailView(species: species)) {
                            SpeciesCard(
                                speciesId: species.id,
                                name: species.name,
                                scientificName: species.scientificName,
                                category: species.category,
                                thumbnailUrl: species.thumbnailUrl.flatMap { URL(string: $0) },
                                description: species.description,
                                seen: seen,
                                sightingCount: sightingCount
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(species.name), \(species.scientificName)")
                        .accessibilityValue(seen ? "Seen \(sightingCount) times" : "Not yet seen")
                        .accessibilityHint("Double tap to view species details")
                    }
                }
                .padding(.horizontal, 16)
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Species catalog, \(viewModel.filteredSpecies.count) species")
            }
        }
    }

    private var categoriesContent: some View {
        Group {
            if viewModel.isLoadingBrowseData {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading categories...")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if viewModel.categorySummaries.isEmpty {
                ContentUnavailableView {
                    Label("No Categories", systemImage: "list.bullet")
                } description: {
                    Text("The wildlife catalog is still loading.")
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 16) {
                    ForEach(viewModel.categorySummaries) { summary in
                        Button {
                            selectedCategory = summary.category
                        } label: {
                            CategoryCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var familiesContent: some View {
        Group {
            if viewModel.isLoadingBrowseData {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Loading families...")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else if viewModel.familySummaries.isEmpty {
                ContentUnavailableView {
                    Label("No Families", systemImage: "leaf")
                } description: {
                    Text("The wildlife catalog is still loading.")
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.familySummaries) { summary in
                        Button {
                            selectedFamily = summary.family
                        } label: {
                            FamilyCard(summary: summary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

private enum WildlifeBrowseMode: CaseIterable {
    case categories
    case families
    case all

    var title: String {
        switch self {
        case .categories:
            return "Categories"
        case .families:
            return "Families"
        case .all:
            return "All"
        }
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
                .background(isSelected ? Color.oceanBlue : Color.trench)
                .foregroundStyle(isSelected ? Color.foam : Color.mist)
                .cornerRadius(20)
        }
    }
}

struct SelectionHeader: View {
    let title: String
    let subtitle: String?
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onBack) {
                Label("Back", systemImage: "chevron.left")
                    .font(.caption)
            }
            .buttonStyle(.bordered)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(Color.foam)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct CategoryCard: View {
    let summary: SpeciesCategorySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: categoryIcon)
                    .foregroundStyle(categoryColor)
                Spacer()
            }

            Text(summary.category.rawValue)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.foam)

            Text("\(summary.speciesCount) species")
                .font(.caption2)
                .foregroundStyle(Color.mist)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.trench)
        .cornerRadius(16)
    }

    private var categoryIcon: String {
        switch summary.category {
        case .fish:
            return "fish.fill"
        case .coral:
            return "sparkles"
        case .mammal:
            return "hare.fill"
        case .invertebrate:
            return "ladybug.fill"
        case .reptile:
            return "tortoise.fill"
        }
    }

    private var categoryColor: Color {
        switch summary.category {
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

struct FamilyCard: View {
    let summary: SpeciesFamilySummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(summary.family.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.foam)
                Spacer()
                Text("\(summary.speciesCount)")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }

            Text(summary.family.scientificName)
                .font(.caption2)
                .foregroundStyle(Color.mist)
                .italic()

            Text(summary.family.category.rawValue)
                .font(.caption2)
                .foregroundStyle(Color.mist)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.trench)
        .cornerRadius(14)
    }
}

struct SpeciesCard: View {
    let speciesId: String
    let name: String
    let scientificName: String
    let category: WildlifeSpecies.Category
    let thumbnailUrl: URL?
    let description: String?
    let seen: Bool
    let sightingCount: Int

    @ScaledMetric(relativeTo: .body) private var imageSize: CGFloat = 80

    var body: some View {
        VStack(spacing: 8) {
            SpeciesImage(
                speciesId: speciesId,
                category: category,
                thumbnailUrl: thumbnailUrl,
                size: imageSize,
                seen: seen,
                speciesName: name
            )

            Text(name)
                .font(SwiftUI.Font.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.foam)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(scientificName)
                .font(.caption2)
                .foregroundStyle(Color.mist)
                .italic()
                .lineLimit(1)

            if let description = description?.trimmingCharacters(in: .whitespacesAndNewlines),
               !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }

            if seen {
                Text("Seen \(sightingCount)x")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.trench)
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
    @Published var categorySummaries: [SpeciesCategorySummary] = []
    @Published var familySummaries: [SpeciesFamilySummary] = []
    @Published var currentSpecies: [WildlifeSpecies] = []
    @Published var filteredSpecies: [WildlifeSpecies] = []
    @Published var sightingCounts: [String: Int] = [:]
    @Published var isLoadingSpecies: Bool = false
    @Published var isLoadingBrowseData: Bool = false

    /// Current map area bounds for "This area" filtering
    var currentAreaBounds: MapBounds?

    private var currentScope: WildlifeScope = .allTime
    private var currentQuery: String = ""
    private var hasLoadedAllSpecies = false
    private var hasLoadedSightingCounts = false
    private let speciesRepository = SpeciesRepository(database: AppDatabase.shared)
    private let database = AppDatabase.shared

    init() {
        loadBrowseData()
    }

    /// Update the scope and reload sighting counts accordingly
    func updateScope(_ scope: WildlifeScope, areaBounds: MapBounds?) {
        currentScope = scope
        currentAreaBounds = areaBounds
        loadSightingCounts()
    }

    func loadBrowseData() {
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.isLoadingBrowseData = true
            }
            defer {
                Task { @MainActor in
                    self.isLoadingBrowseData = false
                }
            }

            do {
                let speciesCount = try self.speciesRepository.count()
                if speciesCount == 0 {
                    do {
                        try DatabaseSeeder.seedIfNeeded()
                    } catch {
                        Log.database.error("Failed to seed wildlife catalog: \(error.localizedDescription)")
                    }
                }

                let categories = try self.speciesRepository.fetchCategorySummaries()
                let families = try self.speciesRepository.fetchFamilySummaries()
                await MainActor.run {
                    self.categorySummaries = categories
                    self.familySummaries = families
                }
            } catch {
                Log.wildlife.error("Error loading browse summaries: \(error.localizedDescription)")
            }
        }
    }

    func loadAllSpeciesIfNeeded(force: Bool = false) {
        guard force || !hasLoadedAllSpecies else { return }
        hasLoadedAllSpecies = true
        loadSpeciesList { try self.speciesRepository.fetchAll() }
    }

    func loadSpecies(for category: WildlifeSpecies.Category, force: Bool = false) {
        if !force, currentSpecies.first?.category == category, !currentSpecies.isEmpty {
            return
        }
        loadSpeciesList { try self.speciesRepository.fetchByCategory(category) }
    }

    func loadSpecies(for family: SpeciesFamily, force: Bool = false) {
        if !force, currentSpecies.first?.familyId == family.id, !currentSpecies.isEmpty {
            return
        }
        loadSpeciesList { try self.speciesRepository.fetchByFamily(family.id) }
    }

    func search(_ query: String) {
        currentQuery = query
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            applyScopeFilter()
            return
        }

        Task { [weak self] in
            do {
                let results = try self?.speciesRepository.search(query) ?? []
                await MainActor.run {
                    self?.filteredSpecies = results
                }
            } catch {
                Log.wildlife.error("Error searching species: \(error.localizedDescription)")
                await MainActor.run {
                    self?.filteredSpecies = []
                }
            }
        }
    }

    private func loadSpeciesList(_ loader: @escaping () throws -> [WildlifeSpecies]) {
        Task { [weak self] in
            await MainActor.run {
                self?.isLoadingSpecies = true
            }
            defer {
                Task { @MainActor [weak self] in
                    self?.isLoadingSpecies = false
                }
            }

            do {
                let species = try loader()
                await MainActor.run {
                    self?.updateSpecies(species)
                }
                self?.loadSightingCounts()
            } catch {
                Log.wildlife.error("Error loading species: \(error.localizedDescription)")
                await MainActor.run {
                    self?.filteredSpecies = []
                }
            }
        }
    }

    @MainActor
    private func updateSpecies(_ species: [WildlifeSpecies]) {
        self.currentSpecies = species
        applyScopeFilter()
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
                }

                self.sightingCounts = counts
                self.hasLoadedSightingCounts = true
                applyScopeFilter()
            } catch {
                Log.wildlife.error("Error loading sighting counts: \(error.localizedDescription)")
            }
        }
    }

    @MainActor
    private func applyScopeFilter() {
        guard currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        if currentScope == .thisArea, hasLoadedSightingCounts {
            filteredSpecies = currentSpecies.filter { sightingCounts[$0.id] ?? 0 > 0 }
        } else {
            filteredSpecies = currentSpecies
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
