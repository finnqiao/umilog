import SwiftUI
import UmiDB
import UmiDesignSystem

/// Floating explorer sheet that hovers above the native tab bar. Pure content —
/// no embedded navigation. Drag handle + persistent header + morphing body.
/// One background, one shadow, one border, one motion system.
struct UnifiedBottomSurface: View {
    // MARK: - Bindings

    @Binding var mode: MapUIMode
    @Binding var detent: SurfaceDetent
    @Binding var exploreFilters: ExploreFilters
    @Binding var filterLens: FilterLens?
    @Binding var entryMode: MapEntryMode

    // MARK: - Data

    /// Filtered sites computed by the parent view using new filter types.
    let filteredSites: [DiveSite]

    /// All sites for search (unfiltered).
    let allSites: [DiveSite]

    /// Loading state from data view model.
    let isLoading: Bool

    /// Optional enriched region detail for the current hierarchy.
    let regionDetail: UmiDB.Region?

    /// Current semantic zoom level for zoom-aware content.
    var zoomLevel: MapZoomLevel = .world

    /// Visible destinations at world zoom.
    var visibleDestinations: [RegionSummary] = []

    /// Visible areas at regional zoom.
    var visibleAreas: [AreaSummary] = []

    /// Nearest area for sparse viewport prompt.
    var nearestArea: AreaSummary?

    /// Nearest region for sparse viewport prompt.
    var nearestRegion: RegionSummary?

    @ObservedObject var dataViewModel: MapViewModel

    // MARK: - Callbacks

    var onSiteTap: (DiveSite) -> Void
    var onDismissInspect: () -> Void
    var onApplyFilters: () -> Void
    var onCancelFilters: () -> Void
    var onSearchSelect: (DiveSite) -> Void
    var onSearchSelectCountry: ((UmiDB.Country) -> Void)?
    var onSearchSelectRegion: ((String, [DiveSite]) -> Void)?
    var onSearchSelectArea: ((String, String, [DiveSite]) -> Void)?
    var onSearchSelectSpecies: ((WildlifeSpecies) -> Void)?
    var onOpenFilter: () -> Void
    var onOpenSearch: () -> Void
    var onNavigateUp: () -> Void
    var onResetToWorld: () -> Void
    var onDrillDown: (String) -> Void
    var onOpenPlan: (String?) -> Void
    var onAddSiteToPlan: (String) -> Void
    var onRemoveSiteFromPlan: (String) -> Void
    var onClosePlan: () -> Void
    var onUpdateSearchQuery: (String) -> Void

    // Area navigation callback
    var onAreaTap: ((AreaSummary) -> Void)?
    var onExpandSearch: (() -> Void)?

    // Near Me callbacks
    var onDeactivateNearMe: (() -> Void)?

    // Cluster expand callbacks (Resy-style)
    var onClusterZoomIn: (() -> Void)?
    var onCloseCluster: (() -> Void)?

    // MARK: - State

    @State private var dragTranslation: CGFloat = 0
    @State private var isAnimating = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Bindings

    /// Binding that reads/writes search query through the reducer context
    private var searchQueryBinding: Binding<String> {
        Binding(
            get: {
                if case .search(let ctx) = mode {
                    return ctx.query
                }
                return ""
            },
            set: { newValue in
                onUpdateSearchQuery(newValue)
            }
        )
    }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let containerHeight = geometry.size.height

            guard containerHeight > 0 else { return AnyView(Color.clear) }

            // The full container height is available for the sheet. The native
            // tab bar already insets this geometry, so the sheet bottom sits
            // flush against the tab bar top automatically.
            let effectiveHeight = containerHeight

            let allowedDetents = SurfaceDetent.allowed(for: mode)
            let baseContentHeight: CGFloat = detent == .hidden ? 0 : detent.height(in: effectiveHeight)
            let draggableDetents = allowedDetents.filter { $0 != .hidden }
            let minContentHeight = draggableDetents.map { $0.height(in: effectiveHeight) }.min() ?? baseContentHeight
            let maxContentHeight = draggableDetents.map { $0.height(in: effectiveHeight) }.max() ?? baseContentHeight

            let adjustedTranslation = SurfaceGestures.computeRubberBandOffset(
                translation: dragTranslation,
                baseHeight: baseContentHeight,
                minHeight: minContentHeight,
                maxHeight: maxContentHeight
            )

            let rawContentHeight = baseContentHeight - adjustedTranslation
            let currentContentHeight = detent == .hidden
                ? 0
                : max(minContentHeight, min(maxContentHeight, rawContentHeight))

            // Normalised drag progress: 0 at the smallest allowed detent,
            // 1 at the largest. Used by content views to morph smoothly.
            let progressDenominator = max(maxContentHeight - minContentHeight, 1)
            let dragProgress = max(0, min(1, (currentContentHeight - minContentHeight) / progressDenominator))

            return AnyView(
                VStack(spacing: 0) {
                    Spacer(minLength: 0)

                    // Outer dock container: one background, one shadow, one clip.
                    surfaceContent(
                        containerHeight: effectiveHeight,
                        dragProgress: dragProgress
                    )
                    .frame(height: currentContentHeight)
                    .clipped()
                    .background(dockBackground)
                    .clipShape(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 28,
                            bottomLeadingRadius: 0,
                            bottomTrailingRadius: 0,
                            topTrailingRadius: 28,
                            style: .continuous
                        )
                    )
                    .shadow(color: Color.black.opacity(0.32), radius: 24, x: 0, y: -8)
                    .simultaneousGesture(
                        dragGesture(containerHeight: effectiveHeight, allowedDetents: allowedDetents)
                    )
                }
                .animation(surfaceAnimation, value: detent)
                .animation(surfaceAnimation, value: mode)
            )
        }
    }

    // MARK: - Animation

    private var surfaceAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    // MARK: - Surface Content

    @ViewBuilder
    private func surfaceContent(containerHeight: CGFloat, dragProgress: CGFloat) -> some View {
        VStack(spacing: 0) {
            dragHandle

            modeContent(containerHeight: containerHeight, dragProgress: dragProgress)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func modeContent(containerHeight: CGFloat, dragProgress: CGFloat) -> some View {
        Group {
            switch mode {
            case .explore(let context):
                ExploreContent(
                    context: context,
                    detent: detent,
                    dragProgress: dragProgress,
                    sites: filteredSites,
                    loading: isLoading,
                    regionDetail: regionDetail,
                    zoomLevel: zoomLevel,
                    filterLens: $filterLens,
                    filterDifficulties: $exploreFilters.difficulty,
                    entryMode: $entryMode,
                    visibleDestinations: visibleDestinations,
                    visibleAreas: visibleAreas,
                    nearestArea: nearestArea,
                    nearestRegion: nearestRegion,
                    onSiteTap: onSiteTap,
                    onOpenFilter: onOpenFilter,
                    onNavigateUp: onNavigateUp,
                    onDrillDown: onDrillDown,
                    onClearFilters: {
                        exploreFilters.reset()
                        filterLens = nil
                        onResetToWorld()
                    },
                    onAddSite: {
                        // TODO: Navigate to site creation flow
                    },
                    onRegionTap: { region in
                        onDrillDown(region.name)
                    },
                    onAreaTap: { area in
                        onAreaTap?(area)
                    },
                    onExpandSearch: {
                        onExpandSearch?()
                    }
                )
                .transition(contentTransition)

            case .inspectSite(let context):
                InspectContent(
                    context: context,
                    site: allSites.first { $0.id == context.siteId },
                    detent: detent,
                    onDismiss: onDismissInspect,
                    onOpenPlan: onOpenPlan
                )
                .transition(contentTransition)

            case .filter:
                FilterContent(
                    exploreFilters: $exploreFilters,
                    filterLens: $filterLens,
                    onApply: onApplyFilters,
                    onCancel: onCancelFilters
                )
                .transition(contentTransition)

            case .search:
                SearchContent(
                    query: searchQueryBinding,
                    sites: allSites,
                    onSelect: onSearchSelect,
                    onSelectCountry: onSearchSelectCountry,
                    onSelectRegion: onSearchSelectRegion,
                    onSelectArea: onSearchSelectArea,
                    onSelectSpecies: onSearchSelectSpecies,
                    onDismiss: { }
                )
                .transition(contentTransition)

            case .plan(let context):
                PlanContent(
                    context: context,
                    allSites: allSites,
                    detent: detent,
                    onAddSite: { onOpenSearch() },
                    onRemoveSite: onRemoveSiteFromPlan,
                    onClose: onClosePlan
                )
                .transition(contentTransition)

            case .clusterExpand(let context):
                ClusterExpandContent(
                    context: context,
                    sites: allSites,
                    detent: detent,
                    onSiteTap: onSiteTap,
                    onZoomIn: onClusterZoomIn ?? {},
                    onClose: onCloseCluster ?? {}
                )
                .transition(contentTransition)

            case .nearMe:
                NearMeContent(
                    sites: filteredSites,
                    nearbyAreas: visibleAreas,
                    userLocation: nil,
                    isLoading: isLoading,
                    onSiteTap: onSiteTap,
                    onAreaTap: { area in onAreaTap?(area) },
                    onDismiss: { onDeactivateNearMe?() }
                )
                .transition(contentTransition)
            }
        }
        .animation(contentAnimation, value: mode.stableId)
    }

    // MARK: - Content Transition

    private var contentTransition: AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .asymmetric(
            insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .scale(scale: 0.98))
        )
    }

    private var contentAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    // MARK: - Drag Handle

    /// Standard iOS-style capsule grabber via the shared `DragHandle` primitive
    /// (plan §3e). No chevrons — the affordance is universally understood.
    private var dragHandle: some View {
        DragHandle(color: .foam)
            .contentShape(Rectangle())
            .onTapGesture {
                let allowed = SurfaceDetent.allowed(for: mode)
                guard let currentIndex = allowed.firstIndex(of: detent) else { return }
                let nextIndex = (currentIndex + 1) % allowed.count
                if reduceMotion {
                    detent = allowed[nextIndex]
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        detent = allowed[nextIndex]
                    }
                }
            }
            .accessibilityLabel("Resize handle")
            .accessibilityHint("Tap to cycle or drag to resize the panel")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Background

    /// Single sheet background: solid navy, one subtle gradient, one top stroke.
    /// No glass, no blur — one material for the whole component.
    private var dockBackground: some View {
        ZStack {
            // Base fill: deep navy, opaque. No translucency so the map never
            // bleeds through and the sheet reads as one solid surface.
            Color(red: 0.07, green: 0.17, blue: 0.29)  // ≈ #122B4A

            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.18)
            )
            .frame(maxHeight: .infinity, alignment: .top)

            // Subtle vertical gradient: slightly lighter at the drag edge,
            // settling toward the base fill below.
            LinearGradient(
                colors: [Color.white.opacity(0.045), Color.clear],
                startPoint: .top,
                endPoint: .init(x: 0.5, y: 0.3)
            )

            // Top stroke: lagoon-tinted at the drag edge, fading quickly.
            // One border for the whole sheet.
            UnevenRoundedRectangle(
                topLeadingRadius: 28,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 28,
                style: .continuous
            )
            .strokeBorder(
                LinearGradient(
                    colors: [Color.lagoon.opacity(0.45), Color.lagoon.opacity(0.04)],
                    startPoint: .top,
                    endPoint: .init(x: 0.5, y: 0.2)
                ),
                lineWidth: 1
            )
        }
    }

    // MARK: - Gesture

    private func dragGesture(containerHeight: CGFloat, allowedDetents: [SurfaceDetent]) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                dragTranslation = value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let translation = value.translation.height

                // Dismiss inspect mode on flick-down at lowest detent
                if case .inspectSite = mode {
                    let lowestDetent = allowedDetents.min { $0.height(in: containerHeight) < $1.height(in: containerHeight) }
                    let isAtLowest = detent == lowestDetent
                    let isFlickingDown = velocity > 500 || translation > 100

                    if isAtLowest && isFlickingDown {
                        if reduceMotion {
                            dragTranslation = 0
                            onDismissInspect()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragTranslation = 0
                                onDismissInspect()
                            }
                        }
                        return
                    }
                }

                let newDetent = SurfaceGestures.finalizeDrag(
                    translation: translation,
                    velocity: velocity,
                    containerHeight: containerHeight,
                    currentDetent: detent,
                    allowedDetents: allowedDetents
                )

                if reduceMotion {
                    dragTranslation = 0
                    detent = newDetent
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        dragTranslation = 0
                        detent = newDetent
                    }
                }
            }
    }
}
