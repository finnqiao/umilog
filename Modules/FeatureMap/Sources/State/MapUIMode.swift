import Foundation

import CoreLocation

/// The current UI mode for the map view.
/// Each mode has an associated context containing mode-specific state.
enum MapUIMode: Equatable {
    case explore(ExploreContext)
    case inspectSite(SiteInspectionContext)
    case filter(FilterContext)
    case search(SearchContext)
    case plan(PlanContext)
    case clusterExpand(ClusterExpandContext)

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

    /// Stable identifier for animation purposes.
    /// Returns a consistent string for each mode type.
    var stableId: String {
        switch self {
        case .explore: return "explore"
        case .inspectSite: return "inspect"
        case .filter: return "filter"
        case .search: return "search"
        case .plan: return "plan"
        case .clusterExpand: return "cluster"
        }
    }

    /// Whether the mode is expanding a cluster.
    var isClusterExpand: Bool {
        if case .clusterExpand = self { return true }
        return false
    }

    /// Extract the cluster expand context if in cluster mode.
    var clusterContext: ClusterExpandContext? {
        if case .clusterExpand(let ctx) = self { return ctx }
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

    /// Optional species ID filter (show only sites with this species).
    var speciesFilter: String?

    /// Create a default explore context.
    init(
        hierarchyLevel: HierarchyLevel = .world,
        filterLens: FilterLens? = nil,
        previewingSite: String? = nil,
        speciesFilter: String? = nil
    ) {
        self.hierarchyLevel = hierarchyLevel
        self.filterLens = filterLens
        self.previewingSite = previewingSite
        self.speciesFilter = speciesFilter
    }
}

// MARK: - Site Inspection Context

/// Context for viewing a specific dive site.
struct SiteInspectionContext: Equatable {
    /// The site being inspected.
    let siteId: String

    /// The explore context to return to when closing.
    let returnContext: ExploreContext

    /// Optional search context to return to when reopening search.
    let returnSearchContext: SearchContext?

    init(
        siteId: String,
        returnContext: ExploreContext,
        returnSearchContext: SearchContext? = nil
    ) {
        self.siteId = siteId
        self.returnContext = returnContext
        self.returnSearchContext = returnSearchContext
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

// MARK: - Plan Context

/// Context for trip planning mode.
struct PlanContext: Equatable {
    /// IDs of sites planned for this trip.
    var plannedSiteIds: [String] = []

    /// Optional trip name.
    var tripName: String?

    /// The initial site that triggered plan mode (if any).
    var initialSiteId: String?

    /// The context to return to when closing.
    let returnContext: ExploreContext

    init(
        plannedSiteIds: [String] = [],
        tripName: String? = nil,
        initialSiteId: String? = nil,
        returnContext: ExploreContext
    ) {
        self.plannedSiteIds = plannedSiteIds
        self.tripName = tripName
        self.initialSiteId = initialSiteId
        self.returnContext = returnContext
    }
}

// MARK: - Cluster Expand Context

/// Context for the Resy-style cluster expand mode.
/// Shows a "site stack" when tapping a cluster of dive sites.
struct ClusterExpandContext: Equatable {
    /// The center coordinate of the cluster.
    let clusterCenter: CLLocationCoordinate2D

    /// Number of sites in the cluster.
    let siteCount: Int

    /// The explore context to return to when closing.
    let returnContext: ExploreContext

    init(
        clusterCenter: CLLocationCoordinate2D,
        siteCount: Int,
        returnContext: ExploreContext
    ) {
        self.clusterCenter = clusterCenter
        self.siteCount = siteCount
        self.returnContext = returnContext
    }

    // Custom Equatable since CLLocationCoordinate2D is not Equatable
    static func == (lhs: ClusterExpandContext, rhs: ClusterExpandContext) -> Bool {
        lhs.clusterCenter.latitude == rhs.clusterCenter.latitude &&
        lhs.clusterCenter.longitude == rhs.clusterCenter.longitude &&
        lhs.siteCount == rhs.siteCount &&
        lhs.returnContext == rhs.returnContext
    }
}
