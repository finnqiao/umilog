import SwiftUI
import UmiDB
import UmiDesignSystem

/// Unified bottom surface that morphs based on the current UI mode.
/// Replaces the old bottom sheet, preview card, and filter overlays.
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

    // Cluster expand callbacks (Resy-style)
    var onClusterZoomIn: (() -> Void)?
    var onCloseCluster: (() -> Void)?

    // MARK: - State

    @GestureState private var dragTranslation: CGFloat = 0
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

            // Guard against invalid container height during layout
            if containerHeight > 0 {
                // Hidden detent: completely hide the surface for ultra-minimal UI
                if detent == .hidden {
                    Color.clear
                        .allowsHitTesting(false)
                } else {
                    let allowedDetents = SurfaceDetent.allowed(for: mode)
                    let baseHeight = detent.height(in: containerHeight)
                    let minHeight = allowedDetents.map { $0.height(in: containerHeight) }.min() ?? baseHeight
                    let maxHeight = allowedDetents.map { $0.height(in: containerHeight) }.max() ?? baseHeight

                    let adjustedTranslation = SurfaceGestures.computeRubberBandOffset(
                        translation: dragTranslation,
                        baseHeight: baseHeight,
                        minHeight: minHeight,
                        maxHeight: maxHeight
                    )

                    // Ensure currentHeight is always valid (positive and finite)
                    let rawHeight = baseHeight - adjustedTranslation
                    let currentHeight = max(minHeight, min(maxHeight, rawHeight))

                    VStack(spacing: 0) {
                        Spacer(minLength: 0)

                        surfaceContent(containerHeight: containerHeight)
                            .frame(height: currentHeight)
                            .background(surfaceBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: Color.black.opacity(0.18), radius: 10, y: -4)
                            // Fix UX-002: Use simultaneousGesture so taps on site cards can still register
                            .simultaneousGesture(dragGesture(containerHeight: containerHeight, allowedDetents: allowedDetents))
                    }
                    .ignoresSafeArea(edges: .bottom)
                    .animation(surfaceAnimation, value: detent)
                    .animation(surfaceAnimation, value: mode)
                }
            }
        }
    }

    // MARK: - Animation

    private var surfaceAnimation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    // MARK: - Surface Content

    @ViewBuilder
    private func surfaceContent(containerHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            dragHandle

            modeContent(containerHeight: containerHeight)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func modeContent(containerHeight: CGFloat) -> some View {
        // Wrap content in a container that applies transitions
        Group {
            switch mode {
            case .explore(let context):
                ExploreContent(
                    context: context,
                    detent: detent,
                    sites: filteredSites,
                    loading: isLoading,
                    regionDetail: regionDetail,
                    filterLens: $filterLens,
                    filterDifficulties: $exploreFilters.difficulty,
                    entryMode: $entryMode,
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
        reduceMotion ? nil : .easeInOut(duration: 0.22)
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.mist.opacity(0.5))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel("Resize handle")
        .accessibilityHint("Drag to expand or collapse the panel")
    }

    // MARK: - Background

    private var surfaceBackground: some View {
        ZStack {
            // Match map background gradient exactly for seamless appearance
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.14, blue: 0.24),  // Map backgroundTop
                    Color(red: 0.04, green: 0.11, blue: 0.19)   // Map backgroundBottom
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Subtle glass overlay for depth and surface distinction
            Rectangle()
                .fill(Color.glass.opacity(0.4))

            // Top border highlight for surface separation
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.ocean.opacity(0.5), Color.ocean.opacity(0.15)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )
        }
    }

    // MARK: - Gesture

    private func dragGesture(containerHeight: CGFloat, allowedDetents: [SurfaceDetent]) -> some Gesture {
        // Fix UX-002: Increased minimum distance from 5 to 10 to reduce interference with tap gestures
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let velocity = value.predictedEndTranslation.height - value.translation.height
                let translation = value.translation.height

                // Check for dismiss gesture: flicking down while in inspect mode at lowest detent
                if case .inspectSite = mode {
                    let lowestDetent = allowedDetents.min { $0.height(in: containerHeight) < $1.height(in: containerHeight) }
                    let isAtLowest = detent == lowestDetent
                    let isFlickingDown = velocity > 500 || translation > 100

                    if isAtLowest && isFlickingDown {
                        // Dismiss inspect mode
                        if reduceMotion {
                            onDismissInspect()
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
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

                if newDetent != detent {
                    if reduceMotion {
                        detent = newDetent
                    } else {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            detent = newDetent
                        }
                    }
                }
            }
    }
}
