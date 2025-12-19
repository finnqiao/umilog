import SwiftUI
import UmiDB

/// Unified bottom surface that morphs based on the current UI mode.
/// Replaces the old bottom sheet, preview card, and filter overlays.
struct UnifiedBottomSurface: View {
    // MARK: - Bindings

    @Binding var mode: MapUIMode
    @Binding var detent: SurfaceDetent
    @Binding var exploreFilters: ExploreFilters
    @Binding var filterLens: FilterLens?

    // MARK: - Data

    @ObservedObject var dataViewModel: MapViewModel

    // MARK: - Callbacks

    var onSiteTap: (DiveSite) -> Void
    var onDismissInspect: () -> Void
    var onApplyFilters: () -> Void
    var onCancelFilters: () -> Void
    var onSearchSelect: (DiveSite) -> Void
    var onOpenFilter: () -> Void
    var onOpenSearch: () -> Void
    var onNavigateUp: () -> Void
    var onDrillDown: (String) -> Void

    // MARK: - State

    @GestureState private var dragTranslation: CGFloat = 0
    @State private var isAnimating = false
    @State private var searchQuery: String = ""

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            let containerHeight = geometry.size.height
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

            let currentHeight = baseHeight - adjustedTranslation

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                surfaceContent(containerHeight: containerHeight)
                    .frame(height: currentHeight)
                    .background(surfaceBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, y: -4)
                    .gesture(dragGesture(containerHeight: containerHeight, allowedDetents: allowedDetents))
            }
            .ignoresSafeArea(edges: .bottom)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: detent)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: mode)
        }
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
        switch mode {
        case .explore(let context):
            ExploreContent(
                context: context,
                detent: detent,
                sites: dataViewModel.filteredSites,
                loading: dataViewModel.loading,
                onSiteTap: onSiteTap,
                onOpenFilter: onOpenFilter,
                onNavigateUp: onNavigateUp,
                onDrillDown: onDrillDown
            )

        case .inspectSite(let context):
            InspectContent(
                context: context,
                site: dataViewModel.sites.first { $0.id == context.siteId },
                detent: detent,
                onDismiss: onDismissInspect
            )

        case .filter:
            FilterContent(
                exploreFilters: $exploreFilters,
                filterLens: $filterLens,
                onApply: onApplyFilters,
                onCancel: onCancelFilters
            )

        case .search:
            SearchContent(
                query: $searchQuery,
                sites: dataViewModel.sites,
                onSelect: onSearchSelect,
                onDismiss: { }
            )
        }
    }

    // MARK: - Drag Handle

    private var dragHandle: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 8)
        }
        .frame(height: 24)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }

    // MARK: - Background

    private var surfaceBackground: some View {
        ZStack {
            // Base glass effect
            Color(uiColor: .systemBackground)
                .opacity(0.95)

            // Thin material overlay
            Rectangle()
                .fill(.ultraThinMaterial)

            // Top border highlight
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.gray.opacity(0.2), lineWidth: 0.5)
        }
    }

    // MARK: - Gesture

    private func dragGesture(containerHeight: CGFloat, allowedDetents: [SurfaceDetent]) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .updating($dragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let newDetent = SurfaceGestures.finalizeDrag(
                    translation: value.translation.height,
                    velocity: value.predictedEndTranslation.height - value.translation.height,
                    containerHeight: containerHeight,
                    currentDetent: detent,
                    allowedDetents: allowedDetents
                )

                if newDetent != detent {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        detent = newDetent
                    }
                }
            }
    }
}

