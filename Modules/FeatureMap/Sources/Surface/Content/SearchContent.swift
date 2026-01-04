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

    // Site type filter state
    @State private var selectedSiteTypes: Set<DiveSite.SiteType> = []
    @State private var nightDivingOnly: Bool = false

    // MARK: - Location

    @ObservedObject private var locationService = LocationService.shared

    // MARK: - Repositories

    private let geographyRepository = GeographyRepository(database: AppDatabase.shared)
    private let speciesRepository = SpeciesRepository(database: AppDatabase.shared)

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

            if query.isEmpty {
                placeholderView
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
        }
        .onChange(of: query) { _, newQuery in
            performDatabaseSearch(query: newQuery)
        }
    }

    // MARK: - Database Search

    private func performDatabaseSearch(query: String) {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            countryResults = []
            speciesResults = []
            return
        }

        // Search countries
        do {
            countryResults = try geographyRepository.searchCountries(query: query, limit: 5)
        } catch {
            countryResults = []
        }

        // Search species
        do {
            speciesResults = try speciesRepository.search(query).prefix(5).map { $0 }
        } catch {
            speciesResults = []
        }
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
        countryResults.isEmpty && filteredRegions.isEmpty && filteredAreas.isEmpty && filteredSites.isEmpty && speciesResults.isEmpty
    }

    private var filteredRegions: [SearchRegionResult] {
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        // Group sites by region and filter by query
        let regionGroups = Dictionary(grouping: sites, by: { $0.region })
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
        let areaGroups = Dictionary(grouping: sites) { site -> String in
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
        guard !query.isEmpty else { return [] }
        let lowercased = query.lowercased()

        var results = sites.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.location.lowercased().contains(lowercased)
        }

        // Apply site type filters
        if !selectedSiteTypes.isEmpty {
            results = results.filter { selectedSiteTypes.contains($0.type) }
        }

        // Apply night diving filter (check tags for "night")
        if nightDivingOnly {
            results = results.filter { site in
                site.tags.contains { $0.lowercased().contains("night") }
            }
        }

        return Array(results.prefix(15))
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

    // MARK: - Placeholder View

    private var placeholderView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("Search for dive sites")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Find sites by name or location")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("No sites found")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Try a different search term")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 48)
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
