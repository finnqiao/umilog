import SwiftUI
import Combine
import UmiDB

/// Unified view model for map UI state management.
/// Uses a reducer pattern for explicit state transitions.
@MainActor
class MapUIViewModel: ObservableObject {
    // MARK: - Published State

    /// The current UI mode.
    @Published private(set) var mode: MapUIMode = .initial

    /// The entry mode — deprecated, always returns .explore.
    /// Trips is now a filter lens, Near Me is an action (not a persistent mode).
    @Published var entryMode: MapEntryMode = .explore

    /// Explore mode filters.
    @Published var exploreFilters: ExploreFilters = .default {
        didSet {
            MapStatePersistence.shared.saveExploreFilters(exploreFilters)
        }
    }

    /// Current semantic zoom level (world/regional/local).
    @Published private(set) var zoomLevel: MapZoomLevel = .world

    /// Active proximity prompt (overlay, not a mode).
    @Published var proximityPrompt: ProximityPromptState?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

    /// Guard against concurrent mode transitions during animations.
    private var isTransitioning = false

    /// Navigation history stack for back navigation.
    @Published private(set) var modeHistory: [MapUIMode] = []
    private let maxHistoryDepth = 5

    /// Cooldown tracking for proximity prompts per site (30 minute cooldown)
    private var promptCooldowns: [String: Date] = [:]
    private let cooldownDuration: TimeInterval = 1800 // 30 minutes

    // MARK: - Initialization

    init() {
        loadPersistedState()
        setupNotificationObservers()
    }

    // MARK: - Actions

    /// Dispatch an action to update state.
    func send(_ action: MapUIAction) {
        // Guard against concurrent transitions during animations
        guard !isTransitioning else { return }

        // Apply reducer
        let newMode = MapUIReducer.reduce(
            state: mode,
            action: action,
            currentFilters: exploreFilters
        )

        // Only update if changed (prevents unnecessary view updates)
        if newMode != mode {
            // Push current mode to history for back navigation
            // (only for major mode changes, not sub-state updates within the same mode)
            if newMode.stableId != mode.stableId {
                pushHistory(mode)
            }

            isTransitioning = true
            mode = newMode
            // Release transition guard after current run loop cycle
            DispatchQueue.main.async { [weak self] in
                self?.isTransitioning = false
            }
        }

        // Handle side effects
        handleSideEffects(for: action)
    }

    /// Navigate back to the previous mode.
    func navigateBack() {
        guard let previousMode = modeHistory.popLast() else { return }
        isTransitioning = true
        mode = previousMode
        DispatchQueue.main.async { [weak self] in
            self?.isTransitioning = false
        }
    }

    /// Whether there's a previous mode to navigate back to.
    var canNavigateBack: Bool {
        !modeHistory.isEmpty
    }

    private func pushHistory(_ mode: MapUIMode) {
        modeHistory.append(mode)
        if modeHistory.count > maxHistoryDepth {
            modeHistory.removeFirst()
        }
    }

    // MARK: - Computed Properties

    /// Extract the explore context if in explore mode.
    var exploreContext: ExploreContext? {
        if case .explore(let ctx) = mode { return ctx }
        return nil
    }

    /// Whether a "My Sites" filter lens is active.
    var isShowingMySites: Bool {
        exploreContext?.filterLens != nil
    }

    /// The current hierarchy level (defaults to world if not in explore).
    var currentHierarchyLevel: HierarchyLevel {
        exploreContext?.hierarchyLevel ?? .world
    }

    /// The inspected site ID if in inspect mode.
    var inspectedSiteId: String? {
        mode.inspectedSiteId
    }

    // MARK: - Zoom Level

    /// Update the semantic zoom level based on the current map region.
    /// Called whenever the map viewport changes.
    func updateZoomLevel(latitudeDelta: Double) {
        let newLevel = MapZoomLevel.from(latitudeDelta: latitudeDelta)
        if newLevel != zoomLevel {
            zoomLevel = newLevel
        }
    }

    // MARK: - Private Methods

    private func loadPersistedState() {
        let persistence = MapStatePersistence.shared

        // Load filters
        exploreFilters = persistence.loadExploreFilters()

        // Load filter lens and apply to initial mode if present
        if let lens = persistence.loadFilterLens() {
            var ctx = ExploreContext()
            ctx.filterLens = lens
            mode = .explore(ctx)
        }
    }

    private func setupNotificationObservers() {
        // Observe geofence arrival notifications
        NotificationCenter.default.publisher(for: .arrivedAtDiveSite)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleGeofenceArrival(notification)
            }
            .store(in: &cancellables)
    }

    private func handleGeofenceArrival(_ notification: Notification) {
        guard let site = notification.userInfo?["site"] as? DiveSite else { return }

        // Check cooldown before showing prompt
        if shouldShowPrompt(for: site.id) {
            send(.showProximityPrompt(site))
        }
    }

    /// Check if a prompt should be shown for a site (respects 30-minute cooldown)
    private func shouldShowPrompt(for siteId: String) -> Bool {
        // Don't show if there's already an active prompt
        if proximityPrompt != nil { return false }

        // Check cooldown
        guard let lastDismiss = promptCooldowns[siteId] else { return true }
        return Date().timeIntervalSince(lastDismiss) > cooldownDuration
    }

    private func handleSideEffects(for action: MapUIAction) {
        let persistence = MapStatePersistence.shared

        switch action {
        // Persist filter lens changes
        case .applyFilterLens(let lens):
            persistence.saveFilterLens(lens)

        case .clearFilterLens:
            persistence.clearFilterLens()

        // Proximity prompt handling
        case .showProximityPrompt(let site):
            proximityPrompt = ProximityPromptState(site: site)

        case .dismissProximityPrompt:
            // Record cooldown time for this site
            if let siteId = proximityPrompt?.site.id {
                promptCooldowns[siteId] = Date()
            }
            proximityPrompt?.isDismissed = true
            // Clear prompt after animation completes
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.proximityPrompt = nil
            }

        case .acceptProximityPrompt:
            if let prompt = proximityPrompt {
                // Post notification to start live log (use object for consistency with receiver)
                NotificationCenter.default.post(
                    name: .startLiveLogRequested,
                    object: prompt.site
                )
            }
            proximityPrompt = nil

        // Filter apply - filters are already persisted via didSet
        case .closeFilter(let apply):
            if apply {
                // Filters were edited in the UI, they'll be saved via exploreFilters didSet
                // when the caller updates exploreFilters after this action
            }

        default:
            break
        }
    }
}

// MARK: - Notification Names
// Note: startLiveLogRequested is defined in UmiCoreKit/Notifications.swift
// arrivedAtDiveSite is defined in UmiLocationKit/GeofenceManager.swift
