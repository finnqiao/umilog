import SwiftUI
import UmiDB
import UmiDesignSystem

/// Content view for Explore mode in the unified bottom surface.
/// Shows site count at peek, breadcrumbs, filter pills, and site list.
struct ExploreContent: View {
    // MARK: - Properties

    let context: ExploreContext
    let detent: SurfaceDetent
    let sites: [DiveSite]
    let loading: Bool
    let regionDetail: UmiDB.Region?

    @Binding var filterLens: FilterLens?
    @Binding var filterDifficulties: Set<DiveSite.Difficulty>
    @Binding var entryMode: MapEntryMode

    // Fallback content data
    var savedSites: [DiveSite] = []
    var recentRegions: [RegionSummary] = []
    var popularRegions: [RegionSummary] = []
    var nearMeSiteCount: Int?

    var onSiteTap: (DiveSite) -> Void
    var onOpenFilter: () -> Void
    var onNavigateUp: () -> Void
    var onDrillDown: (String) -> Void
    var onClearFilters: () -> Void = {}
    var onAddSite: () -> Void = {}
    var onRegionTap: (RegionSummary) -> Void = { _ in }

    // MARK: - State

    @State private var flashId: String?
    @State private var selectedSiteId: String?

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            peekHeader
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            // Show horizontal carousel at peek detent
            if detent == .peek && !sites.isEmpty {
                HorizontalSiteCarousel(
                    sites: sites,
                    onSiteTap: onSiteTap
                )
                .padding(.bottom, 12)
            }

            if detent != .peek {
                // Quick filter pills row
                QuickFilterPillsRow(
                    filterLens: $filterLens,
                    difficulties: $filterDifficulties
                )
                .padding(.bottom, 12)

                if !context.hierarchyLevel.isWorld {
                    BreadcrumbRow(
                        hierarchyLevel: context.hierarchyLevel,
                        onNavigateUp: onNavigateUp,
                        onResetToWorld: { onNavigateUp() }
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                if shouldShowRegionDetail, let regionDetail {
                    RegionDetailCard(region: regionDetail)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                siteList
            }
        }
    }

    // MARK: - Peek Header

    private var peekHeader: some View {
        VStack(spacing: 10) {
            // Entry mode selector
            EntryModeSelector(
                currentMode: $entryMode,
                nearMeSiteCount: nearMeSiteCount
            )

            // Count and filters row
            HStack(spacing: 12) {
                countLabel
                    .font(.subheadline)
                    .foregroundStyle(Color.mist)

                Spacer()

                if let lens = context.filterLens {
                    lensChip(for: lens)
                }

                // Show reset button when any filters are active
                if hasActiveFilters {
                    resetButton
                }

                filterEntryButton
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterLens != nil || !filterDifficulties.isEmpty || !context.hierarchyLevel.isWorld
    }

    private var resetButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                onClearFilters()
            }
            Haptics.soft()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 12, weight: .medium))
                Text("Reset")
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundStyle(Color.foam)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.trench)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Reset all filters")
    }

    private var countLabel: Text {
        if let lens = context.filterLens {
            return Text("\(lens.displayName): \(sites.count)")
        } else {
            return Text("Sites nearby: \(sites.count)")
        }
    }

    private var shouldShowRegionDetail: Bool {
        guard let regionDetail else { return false }
        let hasTagline = regionDetail.tagline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasDescription = regionDetail.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return hasTagline || hasDescription
    }

    private func lensChip(for lens: FilterLens) -> some View {
        HStack(spacing: 4) {
            Image(systemName: lens.iconName)
                .font(.caption2)
            Text(lens.displayName)
                .font(.caption)
        }
        .foregroundStyle(Color.foam)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.trench)
        .clipShape(Capsule())
    }

    private var filterEntryButton: some View {
        Button {
            Haptics.soft()  // Fix UX-007: Add haptic feedback
            onOpenFilter()
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.lagoon)
        }
        .accessibilityLabel("Open filters")
    }

    // MARK: - Site List

    @ViewBuilder
    private var siteList: some View {
        if loading {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        } else if sites.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sites) { site in
                        Button {
                            Haptics.soft()  // Fix UX-007: Add haptic feedback
                            onSiteTap(site)
                        } label: {
                            ExploreSiteRow(site: site, isHighlighted: flashId == site.id)
                        }
                        .buttonStyle(SiteRowButtonStyle())  // Fix UX-002: Use button for reliable tap handling in ScrollView
                        .id(site.id)
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    /// Shows fallback content when viewport is sparse.
    /// Priority: saved sites > recent regions > popular regions.
    private var emptyState: some View {
        Group {
            // If we have fallback data, show rich content
            if !savedSites.isEmpty || !recentRegions.isEmpty || !popularRegions.isEmpty {
                FallbackShelfContent(
                    savedSites: savedSites,
                    recentRegions: recentRegions,
                    popularRegions: popularRegions.isEmpty ? RegionSummary.popular : popularRegions,
                    onSiteTap: onSiteTap,
                    onRegionTap: onRegionTap
                )
            } else {
                // Absolute fallback: use curated regions
                FallbackShelfContent(
                    savedSites: [],
                    recentRegions: [],
                    popularRegions: RegionSummary.popular,
                    onSiteTap: onSiteTap,
                    onRegionTap: onRegionTap
                )
            }
        }
    }

    /// Simple empty state for when filters are applied (user expectation differs).
    private var filteredEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "mappin.slash")
                .font(.system(size: 32))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("No sites found")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Clear filters or zoom out to reveal more dive sites.")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onClearFilters) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Reset All Filters")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.lagoon)
                    .clipShape(Capsule())
                }

                Button(action: onAddSite) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle")
                        Text("Add a New Dive Site")
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.lagoon)
                }
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 24)
    }
}

// MARK: - Region Detail

private struct RegionDetailCard: View {
    let region: UmiDB.Region

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let trimmedTagline = region.tagline?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let trimmedTagline, !trimmedTagline.isEmpty {
                Text(trimmedTagline)
                    .font(.headline)
                    .foregroundStyle(Color.foam)
            } else {
                Text("About \(region.name)")
                    .font(.headline)
                    .foregroundStyle(Color.foam)
            }

            if let description = region.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(Color.mist)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.trench)
        )
    }
}

// MARK: - Site Row

/// Site row for Explore mode list.
private struct ExploreSiteRow: View {
    let site: DiveSite
    var isHighlighted: Bool = false

    private var statusLabel: String {
        if site.visitedCount > 0 {
            return "Logged, \(site.visitedCount) dive(s)"
        } else if site.wishlist {
            return "Wishlist"
        } else {
            return "Not visited"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .accessibilityLabel(statusLabel)

            VStack(alignment: .leading, spacing: 4) {
                Text(site.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.foam)
                    .accessibilityLabel("Site: \(site.name)")

                Text(site.location)
                    .font(.caption)
                    .foregroundStyle(Color.mist)
                    .accessibilityLabel("Location: \(site.location)")

                // Quick facts chips
                HStack(spacing: 6) {
                    ExploreQuickFactChip(text: site.difficulty.rawValue)
                    ExploreQuickFactChip(text: "Max \(Int(site.maxDepth))m")
                    ExploreQuickFactChip(text: "\(Int(site.averageTemp))°C")
                }
                .accessibilityLabel("\(site.difficulty.rawValue) difficulty, maximum depth \(Int(site.maxDepth)) meters, average temperature \(Int(site.averageTemp)) degrees")
            }

            Spacer()

            // Resy-style dive count badge
            if site.visitedCount > 0 {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(site.visitedCount)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color.pinVisited)
                    Text(site.visitedCount == 1 ? "dive" : "dives")
                        .font(.caption2)
                        .foregroundStyle(Color.mist)
                }
                .accessibilityLabel("\(site.visitedCount) dives logged")
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.mist.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color.trench : Color.clear)
        )
        .scaleEffect(isHighlighted ? 1.03 : 1.0)
        .shadow(color: isHighlighted ? Color.lagoon.opacity(0.25) : .clear, radius: 8, y: 4)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isHighlighted)
        .accessibilityElement(children: .combine)
    }

    private var statusColor: Color {
        if site.visitedCount > 0 {
            return Color.pinVisited  // Resy-style green-teal for logged
        } else if site.wishlist {
            return Color.pinFavorite  // Resy-style gold for saved
        } else {
            return Color.pinDefault.opacity(0.3)  // Resy-style cyan for undiscovered
        }
    }
}

// MARK: - Quick Fact Chip

private struct ExploreQuickFactChip: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(Color.mist)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.trench)
            .clipShape(Capsule())
    }
}

// MARK: - Site Row Button Style

/// Custom button style that ensures reliable tap handling inside ScrollView.
/// Uses contentShape and removes default button animations that can conflict with gestures.
private struct SiteRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())  // Fix UX-002: Ensure entire row area is tappable
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}
