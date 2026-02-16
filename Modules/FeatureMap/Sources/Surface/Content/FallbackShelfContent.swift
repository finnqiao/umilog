import SwiftUI
import UmiDB
import UmiDesignSystem

/// Fallback content shown when the map viewport is sparse or empty.
/// Ensures users always see meaningful content in the bottom shelf.
struct FallbackShelfContent: View {
    let savedSites: [DiveSite]
    let recentRegions: [RegionSummary]
    let popularRegions: [RegionSummary]

    var onSiteTap: (DiveSite) -> Void
    var onRegionTap: (RegionSummary) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Saved sites section
                if !savedSites.isEmpty {
                    savedSitesSection
                }

                // Recently viewed regions
                if !recentRegions.isEmpty {
                    recentRegionsSection
                }

                // Popular regions (always show)
                popularRegionsSection

                // Call to action
                explorePrompt
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    // MARK: - Saved Sites

    private var savedSitesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Your Saved Sites", icon: "star.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(savedSites.prefix(6)) { site in
                        SavedSiteCard(site: site) {
                            onSiteTap(site)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Regions

    private var recentRegionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recently Viewed", icon: "clock")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recentRegions) { region in
                        RegionChip(region: region) {
                            onRegionTap(region)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Popular Regions

    private var popularRegionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Popular Regions", icon: "globe")

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(popularRegions) { region in
                    RegionCard(region: region) {
                        onRegionTap(region)
                    }
                }
            }
        }
    }

    // MARK: - Explore Prompt

    private var explorePrompt: some View {
        VStack(spacing: 8) {
            Text("Pick a region to explore")
                .font(.subheadline)
                .foregroundStyle(Color.mist)

            Text("Tap any region above to discover dive sites")
                .font(.caption)
                .foregroundStyle(Color.mist.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }
}

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.lagoon)

            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(Color.foam)
        }
    }
}

// MARK: - Saved Site Card

private struct SavedSiteCard: View {
    let site: DiveSite
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(site.name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)

                Text(site.location)
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: "water.waves")
                        .font(.caption2)
                    Text("\(Int(site.maxDepth))m")
                        .font(.caption2)
                }
                .foregroundStyle(Color.lagoon)
            }
            .padding(10)
            .frame(width: 120)
            .background(Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Region Chip

private struct RegionChip: View {
    let region: RegionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(region.name)
                    .font(.caption)
                    .fontWeight(.medium)

                Text("(\(region.siteCount))")
                    .font(.caption2)
                    .foregroundStyle(Color.mist)
            }
            .foregroundStyle(Color.foam)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Region Card

private struct RegionCard: View {
    let region: RegionSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(region.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.foam)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Color.mist)
                }

                HStack(spacing: 8) {
                    Label(region.countryName, systemImage: "globe")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)

                    Spacer()

                    Text("\(region.siteCount) sites")
                        .font(.caption2)
                        .foregroundStyle(Color.lagoon)
                }
            }
            .padding(12)
            .background(Color.trench)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#if DEBUG
struct FallbackShelfContent_Previews: PreviewProvider {
    static var previews: some View {
        FallbackShelfContent(
            savedSites: [],
            recentRegions: [],
            popularRegions: RegionSummary.popular,
            onSiteTap: { _ in },
            onRegionTap: { _ in }
        )
        .background(Color.abyss)
    }
}
#endif
