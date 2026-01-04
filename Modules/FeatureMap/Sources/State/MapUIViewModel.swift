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

    /// Explore mode filters.
    @Published var exploreFilters: ExploreFilters = .default {
        didSet {
            MapStatePersistence.shared.saveExploreFilters(exploreFilters)
        }
    }

    /// Active proximity prompt (overlay, not a mode).
    @Published var proximityPrompt: ProximityPromptState?

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()

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
        // Apply reducer
        let newMode = MapUIReducer.reduce(
            state: mode,
            action: action,
            currentFilters: exploreFilters
        )

        // Only update if changed (prevents unnecessary view updates)
        if newMode != mode {
            mode = newMode
        }

        // Handle side effects
        handleSideEffects(for: action)
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
