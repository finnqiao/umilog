import Foundation

/// The current UI mode for the map view.
/// Each mode has an associated context containing mode-specific state.
enum MapUIMode: Equatable {
    case explore(ExploreContext)
    case inspectSite(SiteInspectionContext)
    case filter(FilterContext)
    case search(SearchContext)

    /// Default mode on app launch.
    static let initial = MapUIMode.explore(ExploreContext())

    /// Whether the mode is explore (any context).
    var isExplore: Bool {
        if case .explore = self { return true }
        return false
    }

    /// Whether the mode is inspecting a site.
    var isInspecting: Bool {
        if case .inspectSite = self { return true }
        return false
    }

    /// Extract the explore context if in explore mode.
    var exploreContext: ExploreContext? {
        if case .explore(let ctx) = self { return ctx }
        return nil
    }

    /// Extract the inspected site ID if in inspect mode.
    var inspectedSiteId: String? {
        if case .inspectSite(let ctx) = self { return ctx.siteId }
        return nil
    }
}

// MARK: - Explore Context

/// Context for the default explore mode.
struct ExploreContext: Equatable {
    /// Current level in the region/area hierarchy.
    var hierarchyLevel: HierarchyLevel = .world

    /// Optional "My Sites" filter lens.
    var filterLens: FilterLens?

    /// Site ID being previewed (quick peek, not full inspection).
    var previewingSite: String?

    /// Create a default explore context.
    init(
        hierarchyLevel: HierarchyLevel = .world,
        filterLens: FilterLens? = nil,
        previewingSite: String? = nil
    ) {
        self.hierarchyLevel = hierarchyLevel
        self.filterLens = filterLens
        self.previewingSite = previewingSite
    }
}

// MARK: - Site Inspection Context

/// Context for viewing a specific dive site.
struct SiteInspectionContext: Equatable {
    /// The site being inspected.
    let siteId: String

    /// The explore context to return to when closing.
    let returnContext: ExploreContext

    init(siteId: String, returnContext: ExploreContext) {
        self.siteId = siteId
        self.returnContext = returnContext
    }
}

// MARK: - Filter Context

/// Context for the filter selection modal.
struct FilterContext: Equatable {
    /// The current filter settings being edited.
    var exploreFilters: ExploreFilters

    /// The explore context to return to when closing.
    let returnContext: ExploreContext

    init(exploreFilters: ExploreFilters, returnContext: ExploreContext) {
        self.exploreFilters = exploreFilters
        self.returnContext = returnContext
    }
}

// MARK: - Search Context

/// Context for the search interface.
struct SearchContext: Equatable {
    /// The current search query.
    var query: String = ""

    /// The explore context to return to when closing.
    let returnContext: ExploreContext

    init(query: String = "", returnContext: ExploreContext) {
        self.query = query
        self.returnContext = returnContext
    }
}
