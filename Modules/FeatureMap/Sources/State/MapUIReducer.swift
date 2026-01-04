import Foundation
import UmiDB

/// Pure function reducer for map UI state transitions.
/// Enforces valid state transitions based on current mode and action.
enum MapUIReducer {
    /// Reduce the current state with an action to produce a new state.
    /// Invalid transitions return the current state unchanged.
    ///
    /// - Parameters:
    ///   - state: The current UI mode
    ///   - action: The action to apply
    ///   - currentFilters: The current explore filters (needed for filter context)
    /// - Returns: The new UI mode
    static func reduce(
        state: MapUIMode,
        action: MapUIAction,
        currentFilters: ExploreFilters
    ) -> MapUIMode {
        switch (state, action) {
        // MARK: - Explore Mode Transitions

        case (.explore(var ctx), .drillDownToCountry(let countryId)):
            ctx.hierarchyLevel = .country(countryId)
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .drillDownToRegion(let regionId)):
            // Get countryId from current level if at country
            let countryId = ctx.hierarchyLevel.countryId
            ctx.hierarchyLevel = .region(countryId: countryId, regionId: regionId)
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .drillDownToArea(let areaId, let explicitRegion)):
            // Use explicit region if provided, otherwise try to get from current level
            let targetRegion: String
            if let region = explicitRegion {
                targetRegion = region
            } else if case .region(_, let currentRegion) = ctx.hierarchyLevel {
                targetRegion = currentRegion
            } else {
                return state // Can't drill to area without a region
            }
            ctx.hierarchyLevel = .area(regionId: targetRegion, areaId: areaId)
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .navigateUp):
            guard let parent = ctx.hierarchyLevel.parent else {
                return state
            }
            ctx.hierarchyLevel = parent
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .resetToWorld):
            ctx.hierarchyLevel = .world
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .applyFilterLens(let lens)):
            ctx.filterLens = lens
            return .explore(ctx)

        case (.explore(var ctx), .clearFilterLens):
            ctx.filterLens = nil
            return .explore(ctx)

        case (.explore(var ctx), .showPreview(let siteId)):
            ctx.previewingSite = siteId
            return .explore(ctx)

        case (.explore(var ctx), .dismissPreview):
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .promotePreviewToInspect):
            guard let siteId = ctx.previewingSite else {
                return state
            }
            ctx.previewingSite = nil
            let returnContext = ctx
            return .inspectSite(SiteInspectionContext(
                siteId: siteId,
                returnContext: returnContext
            ))

        case (.explore(let ctx), .openSiteInspection(let siteId)):
            var returnContext = ctx
            returnContext.previewingSite = nil
            return .inspectSite(SiteInspectionContext(
                siteId: siteId,
                returnContext: returnContext
            ))

        case (.explore(let ctx), .openFilter):
            return .filter(FilterContext(
                exploreFilters: currentFilters,
                returnContext: ctx
            ))

        case (.explore(let ctx), .openSearch):
            return .search(SearchContext(
                query: "",
                returnContext: ctx
            ))

        // MARK: - Inspect Mode Transitions

        case (.inspectSite(let ctx), .closeSiteInspection):
            return .explore(ctx.returnContext)

        // MARK: - Filter Mode Transitions

        case (.filter(let ctx), .closeFilter):
            return .explore(ctx.returnContext)

        // MARK: - Search Mode Transitions

        case (.search(var ctx), .updateSearchQuery(let query)):
            ctx.query = query
            return .search(ctx)

        case (.search(let ctx), .closeSearch(let selectedSite)):
            if let siteId = selectedSite {
                // Selection made - go to inspect
                return .inspectSite(SiteInspectionContext(
                    siteId: siteId,
                    returnContext: ctx.returnContext
                ))
            } else {
                // No selection - return to explore
                return .explore(ctx.returnContext)
            }

        // MARK: - Plan Mode Transitions

        case (.explore(let ctx), .openPlan(let siteId)):
            var plannedSites: [String] = []
            if let siteId = siteId {
                plannedSites.append(siteId)
            }
            return .plan(PlanContext(
                plannedSiteIds: plannedSites,
                initialSiteId: siteId,
                returnContext: ctx
            ))

        case (.inspectSite(let ctx), .openPlan(let siteId)):
            var plannedSites: [String] = []
            if let siteId = siteId {
                plannedSites.append(siteId)
            }
            return .plan(PlanContext(
                plannedSiteIds: plannedSites,
                initialSiteId: siteId,
                returnContext: ctx.returnContext
            ))

        case (.plan(var ctx), .addSiteToPlan(let siteId)):
            if !ctx.plannedSiteIds.contains(siteId) {
                ctx.plannedSiteIds.append(siteId)
            }
            return .plan(ctx)

        case (.plan(var ctx), .removeSiteFromPlan(let siteId)):
            ctx.plannedSiteIds.removeAll { $0 == siteId }
            return .plan(ctx)

        case (.plan(let ctx), .closePlan):
            return .explore(ctx.returnContext)

        // MARK: - Species Filter Transitions

        case (.explore(var ctx), .showSpeciesSites(let speciesId)):
            ctx.speciesFilter = speciesId
            ctx.previewingSite = nil
            return .explore(ctx)

        case (.explore(var ctx), .clearSpeciesFilter):
            ctx.speciesFilter = nil
            return .explore(ctx)

        case (.search(let ctx), .showSpeciesSites(let speciesId)):
            // From search, go to explore with species filter
            var exploreCtx = ctx.returnContext
            exploreCtx.speciesFilter = speciesId
            return .explore(exploreCtx)

        case (.search(let ctx), .drillDownToCountry(let countryId)):
            // From search, go to explore at country level
            var exploreCtx = ctx.returnContext
            exploreCtx.hierarchyLevel = .country(countryId)
            return .explore(exploreCtx)

        // MARK: - Invalid Transitions

        default:
            // Invalid transitions return state unchanged
            return state
        }
    }
}
