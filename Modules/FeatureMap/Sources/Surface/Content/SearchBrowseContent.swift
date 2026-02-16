import SwiftUI
import UmiDB
import UmiDesignSystem

struct SearchBrowseContent: View {
    let locationContext: String?
    let collectionItems: [SearchCollectionItem]
    let categories: [SearchCategory]
    let selectedCategory: SearchCategory?
    let recentSites: [RecentlyViewedSite]
    let popularRegions: [RegionSummary]

    var onCategoryTap: (SearchCategory) -> Void
    var onRecentSiteTap: (RecentlyViewedSite) -> Void
    var onRegionTap: (RegionSummary) -> Void
    var onLocationClear: (() -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let locationContext {
                    LocationContextChip(title: locationContext, onClear: onLocationClear)
                }

                collectionsSection

                categoriesSection

                if !recentSites.isEmpty {
                    recentSitesSection
                }

                popularRegionsSection
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Collections

    private var collectionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrowseSectionHeader(title: "Collections", icon: "tray.full")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(collectionItems) { item in
                        CollectionCard(
                            title: item.title,
                            icon: item.icon,
                            count: item.count,
                            tint: item.tint,
                            action: item.action
                        )
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }

    // MARK: - Categories

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrowseSectionHeader(title: "Categories", icon: "square.grid.2x2.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(categories) { category in
                    CategoryGridCell(
                        category: category,
                        isSelected: selectedCategory == category,
                        action: { onCategoryTap(category) }
                    )
                }
            }
        }
    }

    // MARK: - Recently Viewed

    private var recentSitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrowseSectionHeader(title: "Recently Viewed", icon: "clock.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentSites.prefix(10)) { site in
                        RecentlyViewedSiteCard(site: site) {
                            onRecentSiteTap(site)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Popular Regions

    private var popularRegionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BrowseSectionHeader(title: "Popular Regions", icon: "globe.americas.fill")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(popularRegions) { region in
                    PopularRegionCard(region: region) {
                        onRegionTap(region)
                    }
                }
            }
        }
    }
}

// MARK: - Collection Item

struct SearchCollectionItem: Identifiable {
    let id: String
    let title: String
    let icon: String
    let count: Int
    let tint: Color
    let action: () -> Void

    init(
        id: String,
        title: String,
        icon: String,
        count: Int,
        tint: Color,
        action: @escaping () -> Void
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.count = count
        self.tint = tint
        self.action = action
    }
}

// MARK: - Section Header

private struct BrowseSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.lagoon)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.foam)
        }
    }
}

// MARK: - Popular Region Card

private struct PopularRegionCard: View {
    let region: RegionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(region.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.foam)
                        .lineLimit(1)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                HStack(spacing: 6) {
                    Label(region.countryName, systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                        .lineLimit(1)

                    Spacer()

                    Text("\(region.siteCount) sites")
                        .font(.caption2)
                        .foregroundStyle(Color.lagoon)
                }
            }
            .padding(12)
            .background(Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(region.name), \(region.countryName)")
    }
}

#if DEBUG
struct SearchBrowseContent_Previews: PreviewProvider {
    static var previews: some View {
        SearchBrowseContent(
            locationContext: "Near Kona, Hawaii",
            collectionItems: [
                SearchCollectionItem(id: "saved", title: "Saved", icon: "heart.fill", count: 12, tint: .pink, action: {}),
                SearchCollectionItem(id: "logged", title: "Logged", icon: "checkmark.seal.fill", count: 5, tint: .lagoon, action: {}),
                SearchCollectionItem(id: "planned", title: "Planned", icon: "calendar", count: 2, tint: .amber, action: {}),
                SearchCollectionItem(id: "near", title: "Near Me", icon: "location.fill", count: 8, tint: .ocean, action: {})
            ],
            categories: SearchCategory.allCases,
            selectedCategory: .wrecks,
            recentSites: [],
            popularRegions: RegionSummary.popular,
            onCategoryTap: { _ in },
            onRecentSiteTap: { _ in },
            onRegionTap: { _ in }
        )
        .background(Color.abyss)
    }
}
#endif
