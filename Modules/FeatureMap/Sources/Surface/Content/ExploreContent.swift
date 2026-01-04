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

    @Binding var filterLens: FilterLens?
    @Binding var filterDifficulties: Set<DiveSite.Difficulty>

    var onSiteTap: (DiveSite) -> Void
    var onOpenFilter: () -> Void
    var onNavigateUp: () -> Void
    var onDrillDown: (String) -> Void
    var onClearFilters: () -> Void = {}
    var onAddSite: () -> Void = {}

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

                siteList
            }
        }
    }

    // MARK: - Peek Header

    private var peekHeader: some View {
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
                        ExploreSiteRow(site: site, isHighlighted: flashId == site.id)
                            .id(site.id)
                            .contentShape(Rectangle())  // Fix UX-002: Define tap hit area
                            .onTapGesture {
                                Haptics.soft()  // Fix UX-007: Add haptic feedback
                                onSiteTap(site)
                            }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private var emptyState: some View {
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
            return Color.lagoon
        } else if site.wishlist {
            return Color.amber
        } else {
            return Color.mist.opacity(0.3)
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
