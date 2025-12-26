import SwiftUI
import UmiDB
import UmiDesignSystem

/// Content view for Search mode in the unified bottom surface.
/// Shows hierarchical search results: Regions → Areas → Sites
struct SearchContent: View {
    // MARK: - Properties

    @Binding var query: String
    let sites: [DiveSite]

    var onSelect: (DiveSite) -> Void
    var onDismiss: () -> Void

    // MARK: - State

    @FocusState private var isSearchFocused: Bool
    @State private var hasAppeared = false
    @State private var expandedSections: Set<SearchSection> = [.sites]

    // MARK: - Search Sections

    private enum SearchSection: String, CaseIterable {
        case regions = "Regions"
        case areas = "Areas"
        case sites = "Sites"

        var icon: String {
            switch self {
            case .regions: return "globe.americas"
            case .areas: return "map"
            case .sites: return "mappin.circle"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            searchField
                .padding(.horizontal, 16)
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
        filteredRegions.isEmpty && filteredAreas.isEmpty && filteredSites.isEmpty
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
        return sites.filter {
            $0.name.lowercased().contains(lowercased) ||
            $0.location.lowercased().contains(lowercased)
        }
        .prefix(15)
        .map { $0 }
    }

    private func parseAreaFromLocation(_ location: String) -> String {
        let components = location.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        return components.first ?? location
    }

    // MARK: - Hierarchical Results List

    private var hierarchicalResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Regions section
                if !filteredRegions.isEmpty {
                    sectionHeader(for: .regions, count: filteredRegions.count)

                    if expandedSections.contains(.regions) {
                        ForEach(filteredRegions, id: \.name) { result in
                            SearchRegionRow(result: result) {
                                // Select first site in region
                                if let site = result.sites.first {
                                    selectSite(site)
                                }
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
                                // Select first site in area
                                if let site = result.sites.first {
                                    selectSite(site)
                                }
                            }
                        }
                    }
                }

                // Sites section
                if !filteredSites.isEmpty {
                    sectionHeader(for: .sites, count: filteredSites.count)

                    if expandedSections.contains(.sites) {
                        ForEach(filteredSites) { site in
                            SearchSiteRow(site: site) {
                                selectSite(site)
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(site.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.foam)

                    Text(site.location)
                        .font(.caption)
                        .foregroundStyle(Color.mist)
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
        .accessibilityLabel("\(site.name), \(site.location)")
        .accessibilityHint("Double tap to view site details")
    }

    private var statusColor: Color {
        if site.visitedCount > 0 {
            return Color.lagoon
        } else if site.wishlist {
            return Color.amber
        } else {
            return Color.mist.opacity(0.3)
        }
    }
}
