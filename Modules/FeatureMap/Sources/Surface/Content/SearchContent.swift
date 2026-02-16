import SwiftUI
import UmiDB
import UmiDesignSystem
import UmiLocationKit
import CoreLocation

/// Content view for Search mode in the unified bottom surface.
/// Shows hierarchical search results: Countries → Regions → Areas → Sites → Species
struct SearchContent: View {
    // MARK: - Properties

    @Binding var query: String
    let sites: [DiveSite]

    var onSelect: (DiveSite) -> Void
    var onSelectCountry: ((UmiDB.Country) -> Void)?
    var onSelectRegion: ((String, [DiveSite]) -> Void)?
    var onSelectArea: ((String, String, [DiveSite]) -> Void)?
    var onSelectSpecies: ((WildlifeSpecies) -> Void)?
    var onDismiss: () -> Void

    // MARK: - State

    @FocusState private var isSearchFocused: Bool
    @State private var hasAppeared = false
    @State private var expandedSections: Set<SearchSection> = [.sites]
    @State private var countryResults: [UmiDB.Country] = []
    @State private var speciesResults: [WildlifeSpecies] = []
    @State private var siteResults: [DiveSite] = []

    // Site type filter state
    @State private var selectedSiteTypes: Set<DiveSite.SiteType> = []
    @State private var nightDivingOnly: Bool = false
    @State private var selectedDifficulty: DiveSite.Difficulty? = nil

    // Browse data
    @State private var savedSites: [DiveSite] = []
    @State private var loggedSites: [DiveSite] = []
    @State private var plannedSites: [DiveSite] = []
    @State private var nearbySites: [DiveSite] = []
    @State private var recentSites: [RecentlyViewedSite] = []
    @State private var popularRegions: [RegionSummary] = RegionSummary.popular

    // Browse filters
    @State private var activeCategory: SearchCategory? = nil
    @State private var activeCollection: SearchCollection? = nil
    @State private var categorySites: [DiveSite] = []
    @State private var isCategoryLoading: Bool = false

    // MARK: - Location

    @ObservedObject private var locationService = LocationService.shared

    // MARK: - Repositories

    private let geographyRepository = GeographyRepository(database: AppDatabase.shared)
    private let speciesRepository = SpeciesRepository(database: AppDatabase.shared)
    private let siteRepository = SiteRepository(database: AppDatabase.shared)

    // MARK: - Search Sections

    private enum SearchSection: String, CaseIterable {
        case countries = "Countries"
        case regions = "Regions"
        case areas = "Areas"
        case sites = "Sites"
        case species = "Species"

        var icon: String {
            switch self {
            case .countries: return "flag"
            case .regions: return "globe.americas"
            case .areas: return "map"
            case .sites: return "mappin.circle"
            case .species: return "fish"
            }
        }
    }

    private enum SearchCollection: String, CaseIterable {
        case saved
        case logged
        case planned
        case nearMe

        var title: String {
            switch self {
            case .saved: return "Saved"
            case .logged: return "Logged"
            case .planned: return "Planned"
            case .nearMe: return "Near Me"
            }
        }

        var icon: String {
            switch self {
            case .saved: return "heart.fill"
            case .logged: return "checkmark.seal.fill"
            case .planned: return "calendar"
            case .nearMe: return "location.fill"
            }
        }

        var tint: Color {
            switch self {
            case .saved: return Color.coralRed
            case .logged: return Color.lagoon
            case .planned: return Color.amber
            case .nearMe: return Color.ocean
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
                .padding(.bottom, 8)

            // Site type filter chips
            SiteTypeFilterRow(
                selectedTypes: $selectedSiteTypes,
                nightDivingOnly: $nightDivingOnly
            )
            .padding(.bottom, 12)

            if shouldShowBrowse {
                SearchBrowseContent(
                    locationContext: locationContextText,
                    collectionItems: collectionItems,
                    categories: SearchCategory.allCases,
                    selectedCategory: activeCategory,
                    recentSites: recentSites,
                    popularRegions: popularRegions,
                    onCategoryTap: handleCategoryTap,
                    onRecentSiteTap: handleRecentSiteTap,
                    onRegionTap: handleRegionTap,
                    onLocationClear: nil
                )
            } else if isCategoryLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if hasNoResults {
                emptyState
            } else {
                hierarchicalResultsList
            }
        }
        .onAppear {
            // Focus the search field on appear (with slight delay for animation)
            if !hasAppeared {
                hasAppeared = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isSearchFocused = true
                }
            }
            loadBrowseData()
        }
        .onChange(of: query) { _, newQuery in
            if !newQuery.isEmpty {
                activeCollection = nil
                activeCategory = nil
                categorySites = []
            }
            performDatabaseSearch(query: newQuery)
        }
        .onChange(of: selectedSiteTypes) { _, _ in
            reconcileActiveCategory()
        }
        .onChange(of: nightDivingOnly) { _, _ in
            reconcileActiveCategory()
        }
        .onChange(of: selectedDifficulty) { _, _ in
            reconcileActiveCategory()
        }
        .onChange(of: locationService.currentLocation) { _, _ in
            loadNearbySites()
        }
    }

    // MARK: - Database Search

    private func performDatabaseSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            countryResults = []
            speciesResults = []
            siteResults = []
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let countries = (try? geographyRepository.searchCountries(query: trimmedQuery, limit: 5)) ?? []
            let species = (try? speciesRepository.search(trimmedQuery).prefix(5).map { $0 }) ?? []
            let sites = (try? siteRepository.search(query: trimmedQuery)) ?? []

            DispatchQueue.main.async {
                countryResults = countries
                speciesResults = species
                siteResults = Array(sites.prefix(200))
            }
        }
    }

    // MARK: - Browse State

    private var hasActiveFilters: Bool {
        !selectedSiteTypes.isEmpty || nightDivingOnly || selectedDifficulty != nil || activeCollection != nil || activeCategory != nil
    }

    private var shouldShowBrowse: Bool {
        query.isEmpty && !hasActiveFilters
    }

    private var locationContextText: String? {
        guard locationService.currentLocation != nil else { return nil }
        if let region = nearbySites.first?.region, !region.isEmpty {
            return "Near \(region)"
        }
        return "Near You"
    }

    private var collectionItems: [SearchCollectionItem] {
        SearchCollection.allCases.map { collection in
            SearchCollectionItem(
                id: collection.rawValue,
                title: collection.title,
                icon: collection.icon,
                count: collectionCount(for: collection),
                tint: collection.tint,
                action: { handleCollectionTap(collection) }
            )
        }
    }

    private func collectionCount(for collection: SearchCollection) -> Int {
        switch collection {
        case .saved: return savedSites.count
        case .logged: return loggedSites.count
        case .planned: return plannedSites.count
        case .nearMe: return nearbySites.count
        }
    }

    private var collectionSites: [DiveSite] {
        switch activeCollection {
        case .saved: return savedSites
        case .logged: return loggedSites
        case .planned: return plannedSites
        case .nearMe: return nearbySites
        case .none: return []
        }
    }

    private var shouldUseCollectionSites: Bool {
        activeCollection != nil && selectedSiteTypes.isEmpty && selectedDifficulty == nil && !nightDivingOnly
    }

    private var shouldUseCategorySites: Bool {
        guard let activeCategory else { return false }

        if activeCategory.isHighBiodiversity {
            return true
        }

        if activeCategory.isNightDiving {
            return nightDivingOnly && selectedSiteTypes.isEmpty && selectedDifficulty == nil
        }

        if let type = activeCategory.siteType {
            return selectedSiteTypes == [type] && selectedDifficulty == nil && !nightDivingOnly
        }

        if let difficulty = activeCategory.difficulty {
            return selectedDifficulty == difficulty && selectedSiteTypes.isEmpty && !nightDivingOnly
        }

        return false
    }

    private func loadBrowseData() {
        DispatchQueue.global(qos: .userInitiated).async {
            let saved = (try? siteRepository.fetchWishlist()) ?? []
            let logged = (try? siteRepository.fetchVisited()) ?? []
            let planned = (try? siteRepository.fetchPlanned()) ?? []
            let recent = MapStatePersistence.shared.loadRecentSites()

            DispatchQueue.main.async {
                savedSites = saved
                loggedSites = logged
                plannedSites = planned
                recentSites = recent
                popularRegions = RegionSummary.popular
            }
        }
        loadNearbySites()
    }

    private func loadNearbySites() {
        guard let location = locationService.currentLocation else {
            nearbySites = []
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let sites = (try? siteRepository.fetchNearby(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                radiusKm: 50,
                limit: 20
            )) ?? []

            DispatchQueue.main.async {
                nearbySites = sites
            }
        }
    }

    private func handleCollectionTap(_ collection: SearchCollection) {
        if activeCollection == collection {
            clearAllFilters()
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            activeCollection = collection
            activeCategory = nil
            query = ""
            selectedSiteTypes.removeAll()
            selectedDifficulty = nil
            nightDivingOnly = false
            categorySites = []
            isCategoryLoading = false
        }
        Haptics.soft()
    }

    private func handleCategoryTap(_ category: SearchCategory) {
        if activeCategory == category {
            clearAllFilters()
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            activeCategory = category
            activeCollection = nil
            query = ""
            selectedSiteTypes.removeAll()
            selectedDifficulty = nil
            nightDivingOnly = false
            categorySites = []
            isCategoryLoading = false
        }
        Haptics.soft()

        if let type = category.siteType {
            selectedSiteTypes = [type]
            loadCategorySites {
                try siteRepository.fetchByType(type, limit: 50)
            }
        } else if let difficulty = category.difficulty {
            selectedDifficulty = difficulty
            loadCategorySites {
                try siteRepository.fetchByDifficulty(difficulty, limit: 50)
            }
        } else if category.isNightDiving {
            nightDivingOnly = true
            let nightSites = sites.filter { site in
                site.tags.contains { $0.lowercased().contains("night") }
            }
            isCategoryLoading = false
            categorySites = Array(nightSites.prefix(50))
        } else if category.isHighBiodiversity {
            loadCategorySites {
                try siteRepository.fetchBySpeciesDiversity(limit: 50)
            }
        }
    }

    private func loadCategorySites(_ loader: @escaping () throws -> [SiteLite]) {
        isCategoryLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let liteSites = (try? loader()) ?? []
            let mappedSites = mapLiteSites(liteSites)

            DispatchQueue.main.async {
                categorySites = mappedSites
                isCategoryLoading = false
            }
        }
    }

    private func mapLiteSites(_ liteSites: [SiteLite]) -> [DiveSite] {
        let lookup = Dictionary(uniqueKeysWithValues: sites.map { ($0.id, $0) })
        return liteSites.compactMap { lookup[$0.id] }
    }

    private func handleRecentSiteTap(_ site: RecentlyViewedSite) {
        guard let fullSite = sites.first(where: { $0.id == site.id }) else { return }
        selectSite(fullSite)
    }

    private func handleRegionTap(_ region: RegionSummary) {
        let regionSites = sites.filter { $0.region == region.name }
        onSelectRegion?(region.name, regionSites)
    }

    private func clearAllFilters() {
        withAnimation(.easeInOut(duration: 0.2)) {
            query = ""
            selectedSiteTypes.removeAll()
            selectedDifficulty = nil
            nightDivingOnly = false
            activeCollection = nil
            activeCategory = nil
            categorySites = []
            isCategoryLoading = false
        }
    }

    private func reconcileActiveCategory() {
        guard let currentCategory = activeCategory else { return }

        if currentCategory.isHighBiodiversity {
            return
        }

        if currentCategory.isNightDiving {
            if nightDivingOnly && selectedSiteTypes.isEmpty && selectedDifficulty == nil {
                return
            }
        }

        if let type = currentCategory.siteType {
            if selectedSiteTypes == [type] && selectedDifficulty == nil && !nightDivingOnly {
                return
            }
        }

        if let difficulty = currentCategory.difficulty {
            if selectedDifficulty == difficulty && selectedSiteTypes.isEmpty && !nightDivingOnly {
                return
            }
        }

        activeCategory = nil
        categorySites = []
        isCategoryLoading = false
    }

    private func trackSiteView(_ site: DiveSite) {
        MapStatePersistence.shared.addRecentSite(site)
        recentSites = MapStatePersistence.shared.loadRecentSites()
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(Color.mist)

            TextField("Search dive sites...", text: $query)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(Color.foam)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()

            if !query.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        query = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.mist)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(12)
        .background(Color.trench)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Hierarchical Results

    private var hasNoResults: Bool {
        if query.isEmpty {
            return hasActiveFilters && filteredSites.isEmpty && !isCategoryLoading
        }
        return countryResults.isEmpty && filteredRegions.isEmpty && filteredAreas.isEmpty && filteredSites.isEmpty && speciesResults.isEmpty
    }

    private var filteredRegions: [SearchRegionResult] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        // Group sites by region and filter by query
        let regionGroups = Dictionary(grouping: activeSites, by: { $0.region })
        return regionGroups.compactMap { (regionName, regionSites) -> SearchRegionResult? in
            guard regionName.lowercased().contains(lowercased) else { return nil }
            return SearchRegionResult(
                name: regionName,
                siteCount: regionSites.count,
                sites: regionSites
            )
        }
        .sorted { $0.name < $1.name }
        .prefix(5)
        .map { $0 }
    }

    private var filteredAreas: [SearchAreaResult] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        // Group sites by area and filter by query
        let areaGroups = Dictionary(grouping: activeSites) { site -> String in
            parseAreaFromLocation(site.location)
        }
        return areaGroups.compactMap { (areaName, areaSites) -> SearchAreaResult? in
            guard areaName.lowercased().contains(lowercased) else { return nil }
            let region = areaSites.first?.region ?? ""
            return SearchAreaResult(
                name: areaName,
                region: region,
                siteCount: areaSites.count,
                sites: areaSites
            )
        }
        .sorted { $0.name < $1.name }
        .prefix(5)
        .map { $0 }
    }

    private var filteredSites: [DiveSite] {
        if query.isEmpty {
            if shouldUseCollectionSites {
                return collectionSites
            }

            if shouldUseCategorySites {
                return categorySites
            }

            guard !selectedSiteTypes.isEmpty || nightDivingOnly || selectedDifficulty != nil else {
                return []
            }

            let baseSites = activeCollection != nil ? collectionSites : sites
            let filtered = applyFilters(to: baseSites)
            return Array(filtered.prefix(25))
        }

        let lowercased = query.lowercased()

        var results = activeSites.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.location.lowercased().contains(lowercased)
        }

        results = applyFilters(to: results)
        return Array(results.prefix(15))
    }

    private var activeSites: [DiveSite] {
        query.isEmpty ? sites : siteResults
    }

    private func applyFilters(to sites: [DiveSite]) -> [DiveSite] {
        var results = sites

        if !selectedSiteTypes.isEmpty {
            results = results.filter { selectedSiteTypes.contains($0.type) }
        }

        if let selectedDifficulty {
            results = results.filter { $0.difficulty == selectedDifficulty }
        }

        if nightDivingOnly {
            results = results.filter { site in
                site.tags.contains { $0.lowercased().contains("night") }
            }
        }

        return results
    }

    private func parseAreaFromLocation(_ location: String) -> String {
        let components = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first ?? location
    }

    // MARK: - Hierarchical Results List

    private var hierarchicalResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Countries section (NEW)
                if !countryResults.isEmpty {
                    sectionHeader(for: .countries, count: countryResults.count)

                    if expandedSections.contains(.countries) {
                        ForEach(countryResults) { (country: UmiDB.Country) in
                            SearchCountryRow(country: country) {
                                selectCountry(country)
                            }
                        }
                    }
                }

                // Regions section
                if !filteredRegions.isEmpty {
                    sectionHeader(for: .regions, count: filteredRegions.count)

                    if expandedSections.contains(.regions) {
                        ForEach(filteredRegions, id: \.name) { result in
                            SearchRegionRow(result: result) {
                                selectRegion(result)
                            }
                        }
                    }
                }

                // Areas section
                if !filteredAreas.isEmpty {
                    sectionHeader(for: .areas, count: filteredAreas.count)

                    if expandedSections.contains(.areas) {
                        ForEach(filteredAreas, id: \.name) { result in
                            SearchAreaRow(result: result) {
                                selectArea(result)
                            }
                        }
                    }
                }

                // Sites section
                if !filteredSites.isEmpty {
                    sectionHeader(for: .sites, count: filteredSites.count)

                    if expandedSections.contains(.sites) {
                        ForEach(filteredSites) { site in
                            SearchSiteRow(
                                site: site,
                                userLocation: locationService.currentLocation
                            ) {
                                selectSite(site)
                            }
                        }
                    }
                }

                // Species section (NEW)
                if !speciesResults.isEmpty {
                    sectionHeader(for: .species, count: speciesResults.count)

                    if expandedSections.contains(.species) {
                        ForEach(speciesResults) { species in
                            SearchSpeciesRow(species: species) {
                                selectSpecies(species)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(for section: SearchSection, count: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                if expandedSections.contains(section) {
                    expandedSections.remove(section)
                } else {
                    expandedSections.insert(section)
                }
            }
            Haptics.tap()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: section.icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Color.lagoon)

                Text(section.rawValue)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.foam)

                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(Color.mist)

                Spacer()

                Image(systemName: expandedSections.contains(section) ? "chevron.down" : "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.trench.opacity(0.5))
        }
        .buttonStyle(.plain)
    }

    private func selectSite(_ site: DiveSite) {
        // Dismiss keyboard first for smooth animation
        isSearchFocused = false

        // Small delay to allow keyboard dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Haptics.soft()
            trackSiteView(site)
            onSelect(site)
        }
    }

    private func selectCountry(_ country: UmiDB.Country) {
        isSearchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Haptics.soft()
            onSelectCountry?(country)
        }
    }

    private func selectRegion(_ result: SearchRegionResult) {
        isSearchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Haptics.soft()
            onSelectRegion?(result.name, result.sites)
        }
    }

    private func selectArea(_ result: SearchAreaResult) {
        isSearchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Haptics.soft()
            onSelectArea?(result.name, result.region, result.sites)
        }
    }

    private func selectSpecies(_ species: WildlifeSpecies) {
        isSearchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            Haptics.soft()
            onSelectSpecies?(species)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text(emptyStateTitle)
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text(emptyStateMessage)
                .font(.subheadline)
                .foregroundStyle(Color.mist)

            if hasActiveFilters || !query.isEmpty {
                Button {
                    clearAllFilters()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.circle")
                            .font(.caption)
                        Text("Clear All")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.foam)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.trench)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear all filters and search")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
    }

    private var emptyStateTitle: String {
        query.isEmpty ? "No sites match your filters" : "No sites match your search"
    }

    private var emptyStateMessage: String {
        if query.isEmpty {
            return "Try a different category or clear filters"
        }
        return "Try a different search term or clear filters"
    }
}

// MARK: - Search Result Models

private struct SearchRegionResult {
    let name: String
    let siteCount: Int
    let sites: [DiveSite]
}

private struct SearchAreaResult {
    let name: String
    let region: String
    let siteCount: Int
    let sites: [DiveSite]
}

// MARK: - Search Result Rows

private struct SearchRegionRow: View {
    let result: SearchRegionResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "globe.americas")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.ocean)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text("\(result.siteCount) dive sites")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.name) region, \(result.siteCount) dive sites")
    }
}

private struct SearchAreaRow: View {
    let result: SearchAreaResult
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "map")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.lagoon)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text("\(result.region) · \(result.siteCount) sites")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(result.name) area in \(result.region), \(result.siteCount) sites")
    }
}

private struct SearchSiteRow: View {
    let site: DiveSite
    let userLocation: CLLocation?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Site thumbnail
                SiteImage(
                    siteId: site.id,
                    siteType: site.type,
                    size: 56,
                    cornerRadius: 8
                )

                VStack(alignment: .leading, spacing: 4) {
                    // Site name with area suffix
                    Text("\(site.name) - \(areaName)")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)
                        .lineLimit(1)

                    HStack(spacing: 12) {
                        // Depth info
                        HStack(spacing: 2) {
                            Image(systemName: "arrow.down")
                                .font(.caption2)
                            Text(depthText)
                                .font(.caption)
                        }
                        .foregroundStyle(Color.mist)

                        // Distance from user
                        if let distance = formattedDistance {
                            Text(distance)
                                .font(.caption)
                                .foregroundStyle(Color.mist)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(site.name), \(areaName), depth \(depthText)")
        .accessibilityHint("Double tap to view site details")
    }

    private var areaName: String {
        let components = site.location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first ?? site.location
    }

    private var depthText: String {
        if site.averageDepth > 0 && site.maxDepth > 0 && site.averageDepth != site.maxDepth {
            return "\(Int(site.averageDepth))-\(Int(site.maxDepth))m"
        } else if site.maxDepth > 0 {
            return "\(Int(site.maxDepth))m"
        } else {
            return "--m"
        }
    }

    private var formattedDistance: String? {
        guard let userLocation else { return nil }
        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
        let distanceMeters = userLocation.distance(from: siteLocation)
        let distanceKm = distanceMeters / 1000

        if distanceKm < 1 {
            return String(format: "%.0fm", distanceMeters)
        } else if distanceKm < 100 {
            return String(format: "%.0f km", distanceKm)
        } else {
            return String(format: "%.0f km", distanceKm)
        }
    }
}

// MARK: - Country Row

private struct SearchCountryRow: View {
    let country: UmiDB.Country
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(countryFlag)
                    .font(.title2)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(country.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text(country.continent)
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(country.name), \(country.continent)")
    }

    private var countryFlag: String {
        let base: UInt32 = 127397
        var flag = ""
        // Country ID is the ISO code string
        for scalar in country.id.uppercased().unicodeScalars {
            if let unicode = Unicode.Scalar(base + scalar.value) {
                flag.append(Character(unicode))
            }
        }
        return flag.isEmpty ? "🌍" : flag
    }
}

// MARK: - Species Row

private struct SearchSpeciesRow: View {
    let species: WildlifeSpecies
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: categoryIcon)
                    .font(.system(size: 18))
                    .foregroundStyle(categoryColor)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(species.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text(species.scientificName)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.mist)
                }

                Spacer()

                // Category badge
                Text(species.category.rawValue)
                    .font(.caption2)
                    .foregroundStyle(categoryColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(categoryColor.opacity(0.15))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(species.name), \(species.scientificName)")
    }

    private var categoryIcon: String {
        switch species.category {
        case .fish: return "fish"
        case .coral: return "leaf"
        case .mammal: return "hare"
        case .invertebrate: return "ant"
        case .reptile: return "lizard"
        }
    }

    private var categoryColor: Color {
        switch species.category {
        case .fish: return Color.lagoon
        case .coral: return Color.coralRed
        case .mammal: return Color.ocean
        case .invertebrate: return Color.mist
        case .reptile: return Color.seaGreen
        }
    }
}
