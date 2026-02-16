import Foundation
import CoreLocation
import UmiDB

/// Actions that can be dispatched to change the map UI state.
/// Processed by MapUIReducer to produce state transitions.
enum MapUIAction: Equatable {
    // MARK: - Hierarchy Navigation

    /// Drill down into a specific country.
    case drillDownToCountry(String)

    /// Drill down into a specific region.
    case drillDownToRegion(String)

    /// Drill down into a specific area within a region.
    /// If region is provided, navigates directly to that area in the given region.
    /// If region is nil, uses the current region from the hierarchy level.
    case drillDownToArea(String, region: String?)

    /// Navigate up one level in the hierarchy.
    case navigateUp

    /// Reset to world view.
    case resetToWorld

    // MARK: - Filter Lens

    /// Apply a "My Sites" filter lens.
    case applyFilterLens(FilterLens)

    /// Clear the current filter lens.
    case clearFilterLens

    // MARK: - Preview (within Explore)

    /// Show a quick preview of a site (within explore mode).
    case showPreview(String)

    /// Dismiss the current preview.
    case dismissPreview

    /// Promote the current preview to full inspection mode.
    case promotePreviewToInspect

    // MARK: - Mode Transitions

    /// Open full inspection view for a site.
    case openSiteInspection(String)

    /// Close site inspection and return to explore.
    case closeSiteInspection

    /// Open the filter selection modal.
    case openFilter

    /// Close filter modal, optionally applying changes.
    case closeFilter(apply: Bool)

    /// Open the search interface.
    case openSearch

    /// Close search, optionally selecting a site.
    case closeSearch(selectedSite: String?)

    /// Update the search query.
    case updateSearchQuery(String)

    // MARK: - Proximity Prompt

    /// Show the proximity log prompt for a nearby site.
    case showProximityPrompt(DiveSite)

    /// Dismiss the proximity prompt.
    case dismissProximityPrompt

    /// Accept the proximity prompt (start logging).
    case acceptProximityPrompt

    // MARK: - Trip Planning

    /// Open trip planning mode, optionally starting with a site.
    case openPlan(siteId: String?)

    /// Add a site to the current plan.
    case addSiteToPlan(String)

    /// Remove a site from the current plan.
    case removeSiteFromPlan(String)

    /// Close plan mode and return to explore.
    case closePlan

    // MARK: - Species Filtering

    /// Show sites where a specific species can be found.
    case showSpeciesSites(String)

    /// Clear the species filter.
    case clearSpeciesFilter

    // MARK: - Cluster Expand

    /// Open cluster expand mode showing sites at the given cluster.
    case openClusterExpand(ClusterExpandContext)

    /// Close cluster expand and return to explore.
    case closeClusterExpand
}
