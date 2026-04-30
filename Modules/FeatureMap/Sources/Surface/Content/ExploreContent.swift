import SwiftUI
import UmiCoreKit
import UmiDB
import UmiDesignSystem

/// Content view for Explore mode in the unified bottom surface.
/// Adapts content based on semantic zoom level:
/// - World: destination cards
/// - Regional: area cards
/// - Local: site list
struct ExploreContent: View {
    // MARK: - Properties

    let context: ExploreContext
    let detent: SurfaceDetent
    /// Continuous 0–1 fraction of the current drag position (0 = smallest detent,
    /// 1 = largest). Used to cross-fade peek / browse / expanded layers so the
    /// sheet contents morph smoothly as the user drags, instead of snapping at
    /// detent thresholds.
    var dragProgress: CGFloat = 0
    let sites: [DiveSite]
    let loading: Bool
    let selectedSiteId: String?
    let regionDetail: UmiDB.Region?
    let zoomLevel: MapZoomLevel

    @Binding var filterLens: FilterLens?
    @Binding var filterDifficulties: Set<DiveSite.Difficulty>
    @Binding var entryMode: MapEntryMode

    // Semantic zoom data
    var visibleDestinations: [RegionSummary] = []
    var visibleAreas: [AreaSummary] = []

    // Fallback content data
    var savedSites: [DiveSite] = []
    var recentRegions: [RegionSummary] = []
    var popularRegions: [RegionSummary] = []
    var nearMeSiteCount: Int?

    // Sparse viewport data
    var nearestArea: AreaSummary?
    var nearestRegion: RegionSummary?

    var onSiteTap: (DiveSite) -> Void
    var onOpenFilter: () -> Void
    var onNavigateUp: () -> Void
    var onDrillDown: (String) -> Void
    var onClearFilters: () -> Void = {}
    var onAddSite: () -> Void = {}
    var onRegionTap: (RegionSummary) -> Void = { _ in }
    var onAreaTap: (AreaSummary) -> Void = { _ in }
    var onOpenSearch: () -> Void = {}
    var onExpandSearch: () -> Void = {}

    // MARK: - State

    @State private var flashId: String?

    // MARK: - Body

    var body: some View {
        Group {
            if shouldShowRestingPeek {
                peekLayout
            } else {
                // Layered cross-fade: all three layouts coexist, opacity-driven by the
                // continuous drag progress. As the user drags the sheet, the content
                // morphs smoothly — no snap-to-detent content swaps, no ghosting. The
                // active layer (highest opacity) owns hit testing.
                ZStack(alignment: .top) {
                    expandedLayout
                        .opacity(expandedOpacity)
                        .allowsHitTesting(expandedOpacity > 0.5)

                    browseLayout
                        .opacity(browseOpacity)
                        .allowsHitTesting(browseOpacity > 0.5)

                    peekLayout
                        .opacity(peekOpacity)
                        .allowsHitTesting(peekOpacity > 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Layer Opacity Curves

    /// Peek layer is fully visible at the smallest detent and fades out as the
    /// user drags toward medium. Cleared by the time browse content reads.
    private var peekOpacity: Double {
        Double(1 - smoothstep(0.0, 0.22, dragProgress))
    }

    /// Browse (carousel) layer fades in as we leave peek and fades out as we
    /// approach expanded — a bell curve centred on the medium detent.
    private var browseOpacity: Double {
        let fadeIn = Double(smoothstep(0.05, 0.30, dragProgress))
        let fadeOut = Double(smoothstep(0.55, 0.85, dragProgress))
        return fadeIn * (1 - fadeOut)
    }

    /// Expanded layer fades in as the sheet approaches its largest detent.
    private var expandedOpacity: Double {
        Double(smoothstep(0.55, 0.92, dragProgress))
    }

    /// Hermite smoothstep — gives a soft S-curve interpolation in [0, 1].
    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = max(0, min(1, (x - edge0) / max(edge1 - edge0, 0.0001)))
        return t * t * (3 - 2 * t)
    }

    private var shouldShowRestingPeek: Bool {
        detent == .peek && dragProgress <= 0.04
    }

    private var shouldShowPeekSitePreview: Bool {
        zoomLevel == .local && !sites.isEmpty
    }

    private var shouldShowBrowseSiteRows: Bool {
        zoomLevel == .local && !sites.isEmpty
    }

    private var peekFallbackText: String {
        if loading {
            return "Loading dive sites..."
        }

        switch zoomLevel {
        case .world:
            return visibleDestinations.isEmpty ? "Browse dive destinations" : "Browse destinations"
        case .regional:
            return visibleAreas.isEmpty ? "Browse dive sites" : "Browse dive areas"
        case .local:
            return "Search nearby dive sites"
        }
    }

    // MARK: - Peek Layout

    /// Peek: hero title + sort pill + first nearby site preview (or hint when no sites).
    private var peekLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Hero title row
            HStack(alignment: .center, spacing: 10) {
                if shouldShowBackButton {
                    sheetBackButton
                }

                Image(systemName: "water.waves")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.lagoon)

                Text(peekHeroTitle)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.foam)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Spacer()

                Image(systemName: "chevron.up")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.lagoon.opacity(0.75))

                filterEntryButton
            }

            // First nearby site preview is only useful once the map is local.
            // At world/regional zoom it reads like a random recommendation.
            if shouldShowPeekSitePreview, let first = sites.first {
                Button {
                    onSiteTap(first)
                    Haptics.soft()
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(peekDifficultyColor(first.difficulty))
                            .frame(width: 6, height: 6)
                        Text(first.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.foam)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(first.maxDepth))m · \(first.type.rawValue)")
                            .font(.caption)
                            .foregroundStyle(Color.mist)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color.mist.opacity(0.5))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.kelp.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    onExpandSearch()
                    Haptics.soft()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: loading ? "hourglass" : "chevron.up")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.lagoon.opacity(0.85))
                        Text(peekFallbackText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.mist.opacity(0.85))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.kelp.opacity(0.34))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 20)
        .padding(.trailing, 20)
        .padding(.top, 8)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var hasBrowseContent: Bool {
        switch zoomLevel {
        case .world:
            return !visibleDestinations.isEmpty
        case .regional:
            return !visibleAreas.isEmpty || !sites.isEmpty
        case .local:
            return !sites.isEmpty
        }
    }

    private var compactBrowseFallback: some View {
        Button {
            onExpandSearch()
            Haptics.soft()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: loading ? "hourglass" : "water.waves")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.lagoon)

                VStack(alignment: .leading, spacing: 2) {
                    Text(loading ? "Loading dive sites" : "Explore dive sites")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.foam)

                    Text(loading ? "The map is filling in nearby sites." : "Drag up or search to find sites.")
                        .font(.caption)
                        .foregroundStyle(Color.mist.opacity(0.78))
                        .lineLimit(1)
                }

                Spacer()

                if !loading {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.mist.opacity(0.65))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .background(Color.kelp.opacity(0.34))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func peekDifficultyColor(_ difficulty: DiveSite.Difficulty) -> Color {
        switch difficulty {
        case .beginner: return .difficultyBeginner
        case .intermediate: return .difficultyIntermediate
        case .advanced: return .difficultyAdvanced
        }
    }

    private var peekHeroTitle: String {
        switch zoomLevel {
        case .world:
            return visibleDestinations.isEmpty ? "Discover Dive Sites" : "Dive Destinations Worldwide"
        case .regional:
            if let regionId = context.hierarchyLevel.regionId {
                return "Sites in \(regionId)"
            }
            return "Dive Sites in This Region"
        case .local:
            let count = sites.count
            return count > 0 ? "\(count) Site\(count == 1 ? "" : "s") Nearby" : "No Sites Here"
        }
    }

    // MARK: - Browse Layout

    /// Medium-height state: title row + carousel + first few site rows to fill the sheet.
    private var browseLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            browseHeaderRow
                .padding(.leading, 20)
                .padding(.trailing, 20)
                .padding(.top, 4)

            if hasBrowseContent {
                peekCarousel
                    .padding(.top, 12)

                // Fill remaining medium-detent space with the first few site rows.
                // Without these the carousel (~110pt) leaves 150-200pt of dead space.
                if shouldShowBrowseSiteRows {
                    Divider()
                        .opacity(0.15)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                    VStack(spacing: 0) {
                        ForEach(Array(sites.prefix(4).enumerated()), id: \.element.id) { index, site in
                            SiteRow(site: site, isHighlighted: selectedSiteId == site.id)
                                .onTapGesture {
                                    onSiteTap(site)
                                }
                            if index < min(sites.count, 4) - 1 {
                                Divider()
                                    .padding(.leading, 36)
                                    .opacity(0.12)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                }
            } else {
                compactBrowseFallback
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Browse Header

    private var browseHeaderRow: some View {
        HStack(spacing: 8) {
            if shouldShowBackButton {
                sheetBackButton
            }

            dynamicTitle
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.foam)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer()

            filterEntryButton
        }
    }

    private var shouldShowBackButton: Bool {
        !context.hierarchyLevel.isWorld
    }

    private var sheetBackButton: some View {
        Button {
            Haptics.soft()
            onNavigateUp()
        } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.lagoon)
                .frame(width: 30, height: 30)
                .background(Color.trench.opacity(0.72))
                .clipShape(Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    // MARK: - Expanded Layout

    /// Expanded state: sheet owns search. A sticky header container holds the
    /// search row + filter chips (+ optional breadcrumb) with a subtle background
    /// tint so it reads as a fixed anchor above the scrollable list.
    private var expandedLayout: some View {
        VStack(spacing: 0) {
            // Sticky header — fixed at top of sheet, owns search + chips.
            VStack(spacing: 10) {
                expandedSearchRow

                QuickFilterPillsRow(
                    filterLens: $filterLens,
                    difficulties: $filterDifficulties
                )

                if !context.hierarchyLevel.isWorld {
                    BreadcrumbRow(
                        hierarchyLevel: context.hierarchyLevel,
                        onNavigateUp: onNavigateUp,
                        onResetToWorld: { onNavigateUp() }
                    )
                }

                // Compact spatial anchor: keeps the user oriented without
                // duplicating the full peek summary.
                expandedContextLine
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .background(Color.white.opacity(0.02))

            // Region context card (optional, below sticky header).
            if shouldShowRegionDetail, let regionDetail {
                RegionDetailCard(region: regionDetail)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)
            }

            zoomAwareList
        }
    }

    /// A single compact line that gives spatial orientation in expanded mode —
    /// site count + region/area context — so the list never feels placeless.
    @ViewBuilder
    private var expandedContextLine: some View {
        let label = expandedContextLabel
        if let label {
            HStack(spacing: 0) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.mist.opacity(0.65))
                Spacer()
            }
        }
    }

    private var expandedContextLabel: String? {
        let count = sites.count
        guard count > 0 else { return nil }

        switch zoomLevel {
        case .world:
            if !visibleDestinations.isEmpty {
                return "\(visibleDestinations.count) destination\(visibleDestinations.count == 1 ? "" : "s") in view"
            }
            if !popularRegions.isEmpty {
                return "\(popularRegions.count) popular destination\(popularRegions.count == 1 ? "" : "s")"
            }
            return nil
        case .regional:
            if let regionId = context.hierarchyLevel.regionId {
                return "\(count) site\(count == 1 ? "" : "s") in \(regionId)"
            }
            return "\(count) dive site\(count == 1 ? "" : "s")"
        case .local:
            if let areaId = context.hierarchyLevel.areaId {
                return "\(count) site\(count == 1 ? "" : "s") near \(areaId)"
            } else if let regionId = context.hierarchyLevel.regionId {
                return "\(count) site\(count == 1 ? "" : "s") near \(regionId)"
            }
            return "\(count) nearby dive site\(count == 1 ? "" : "s")"
        }
    }

    private var expandedSearchRow: some View {
        HStack(spacing: 10) {
            // Search tap target — opens search mode.
            Button {
                Haptics.soft()
                onOpenSearch()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.mist)
                    Text(expandedSearchPlaceholder)
                        .font(.subheadline)
                        .foregroundStyle(Color.mist.opacity(0.75))
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search dive sites")

            // Filter entry — distinct from the search tap target.
            Button {
                Haptics.soft()
                onOpenFilter()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(hasActiveFilters ? Color.foam : Color.lagoon)
                    .frame(width: 30, height: 30)
                    .background(hasActiveFilters ? Color.lagoon : Color.trench)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(hasActiveFilters ? "Filters (active)" : "Filters")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Color.trench.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var expandedSearchPlaceholder: String {
        "Search sites, species, or regions"
    }

    // MARK: - Peek Carousel (zoom-aware)

    @ViewBuilder
    private var peekCarousel: some View {
        switch zoomLevel {
        case .world:
            if !visibleDestinations.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleDestinations) { region in
                            DestinationChipCard(region: region) {
                                onRegionTap(region)
                                Haptics.soft()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        case .regional:
            if !visibleAreas.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(visibleAreas) { area in
                            AreaChipCard(area: area) {
                                onAreaTap(area)
                                Haptics.soft()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        case .local:
            if !sites.isEmpty {
                HorizontalSiteCarousel(sites: sites, onSiteTap: onSiteTap, onSeeAll: onExpandSearch)
            }
        }
    }

    // MARK: - Dynamic Title

    /// Dynamic title that changes based on zoom level and context.
    private var dynamicTitle: Text {
        if let lens = context.filterLens {
            return Text("\(lens.displayName): \(sites.count)")
        }

        switch zoomLevel {
        case .world:
            if visibleDestinations.isEmpty {
                return Text("Discover dive sites")
            }
            return Text("\(visibleDestinations.count) destinations in view")
        case .regional:
            if let regionId = context.hierarchyLevel.regionId {
                return Text("\(regionId) \u{00B7} \(sites.count) sites in view")
            }
            return Text("\(sites.count) sites in view")
        case .local:
            if let areaId = context.hierarchyLevel.areaId {
                return Text("\(areaId) \u{00B7} \(sites.count) sites in map area")
            }
            return Text("\(sites.count) sites in map area")
        }
    }

    private var hasActiveFilters: Bool {
        !filterDifficulties.isEmpty
    }

    private var shouldShowRegionDetail: Bool {
        guard let regionDetail else { return false }
        let hasTagline = regionDetail.tagline?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let hasDescription = regionDetail.description?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return hasTagline || hasDescription
    }

    private var filterEntryButton: some View {
        Button {
            Haptics.soft()  // Fix UX-007: Add haptic feedback
            onOpenFilter()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 13, weight: .semibold))
                Text(filterButtonTitle)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(hasActiveFilters ? Color.foam : Color.lagoon)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(hasActiveFilters ? Color.lagoon : Color.lagoon.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(Color.lagoon.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(hasActiveFilters ? "Filters (active)" : "Open filters")
    }

    private var filterButtonTitle: String {
        if hasActiveFilters {
            return "Filters (\(activeFilterCount))"
        }
        return "Filters"
    }

    private var activeFilterCount: Int {
        filterDifficulties.count
    }

    // MARK: - Zoom-Aware List

    @ViewBuilder
    private var zoomAwareList: some View {
        if loading {
            ProgressView()
                .progressViewStyle(.circular)
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
        } else {
            switch zoomLevel {
            case .world:
                destinationList
            case .regional:
                areaList
            case .local:
                siteList
            }
        }
    }

    // MARK: - Destination List (World Zoom)

    @ViewBuilder
    private var destinationList: some View {
        if visibleDestinations.isEmpty {
            if hasActiveFilters {
                if filterLens == .logged && filterDifficulties.isEmpty {
                    loggedLensEmptyState
                } else {
                    filteredEmptyState
                }
            } else {
                emptyState
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visibleDestinations) { region in
                        DestinationCard(region: region) {
                            onRegionTap(region)
                            Haptics.soft()
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Area List (Regional Zoom)

    @ViewBuilder
    private var areaList: some View {
        if visibleAreas.isEmpty && sites.isEmpty {
            if hasActiveFilters {
                if filterLens == .logged && filterDifficulties.isEmpty {
                    loggedLensEmptyState
                } else {
                    filteredEmptyState
                }
            } else {
                sparseViewport
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(visibleAreas) { area in
                        AreaCard(area: area) {
                            onAreaTap(area)
                            Haptics.soft()
                        }
                    }

                    // If we have some sites but no areas, show sites
                    if visibleAreas.isEmpty && !sites.isEmpty {
                        ForEach(sites) { site in
                            Button {
                                Haptics.soft()
                                onSiteTap(site)
                            } label: {
                                ExploreSiteRow(site: site, isHighlighted: selectedSiteId == site.id || flashId == site.id)
                            }
                            .buttonStyle(SiteRowButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, visibleAreas.isEmpty ? 0 : 16)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Site List (Local Zoom)

    @ViewBuilder
    private var siteList: some View {
        if sites.isEmpty {
            if hasActiveFilters {
                if filterLens == .logged && filterDifficulties.isEmpty {
                    loggedLensEmptyState
                } else {
                    filteredEmptyState
                }
            } else {
                sparseViewport
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(sites) { site in
                        Button {
                            Haptics.soft()
                            onSiteTap(site)
                        } label: {
                            ExploreSiteRow(site: site, isHighlighted: selectedSiteId == site.id || flashId == site.id)
                        }
                        .buttonStyle(SiteRowButtonStyle())
                        .id(site.id)
                    }
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Sparse Viewport

    @ViewBuilder
    private var sparseViewport: some View {
        if nearestArea != nil || nearestRegion != nil {
            SparseViewportPrompt(
                nearestArea: nearestArea,
                nearestRegion: nearestRegion,
                onExpandSearch: onExpandSearch,
                onNavigateToArea: { area in onAreaTap(area) },
                onNavigateToRegion: { region in onRegionTap(region) }
            )
        } else {
            emptyState
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

            Text("No Dive Sites Found")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Try clearing your filters or zooming out to discover more underwater adventures.")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button(action: onClearFilters) {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle")
                        Text("Clear All Filters")
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

    private var loggedLensEmptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(Color.mist.opacity(0.5))

            Text("No dives logged yet")
                .font(.headline)
                .foregroundStyle(Color.foam)

            Text("Log your first dive and it will appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.mist)
                .multilineTextAlignment(.center)

            Button {
                NotificationCenter.default.post(name: .showLogLauncher, object: nil)
            } label: {
                Label("Log a Dive", systemImage: "plus.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.foam)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.lagoon)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 32)
        .padding(.top, 24)
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
            RoundedRectangle(cornerRadius: 2)
                .fill(isHighlighted ? Color.lagoon : Color.clear)
                .frame(width: 4, height: 48)

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
                    ExploreQuickFactChip(text: site.type.rawValue.capitalized)
                    ExploreQuickFactChip(text: "Max \(Int(site.maxDepth))m")
                }
                .accessibilityLabel("\(site.difficulty.rawValue) difficulty, \(site.type.rawValue) site, maximum depth \(Int(site.maxDepth)) meters")
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
                .foregroundStyle(Color.mist.opacity(0.72))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isHighlighted ? Color.lagoon.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.lagoon.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .scaleEffect(isHighlighted ? 1.01 : 1.0)
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
