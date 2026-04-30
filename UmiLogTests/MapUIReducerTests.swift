import XCTest
import CoreLocation
@testable import FeatureMap
@testable import UmiDB

final class MapUIReducerTests: XCTestCase {
    private let defaultFilters = ExploreFilters.default

    // MARK: - Hierarchy Navigation Tests

    func testDrillDownToRegion() {
        let state = MapUIMode.explore(ExploreContext())
        let result = MapUIReducer.reduce(
            state: state,
            action: .drillDownToRegion("Caribbean"),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
    }

    func testDrillDownToArea() {
        let state = MapUIMode.explore(ExploreContext(hierarchyLevel: .region(countryId: nil, regionId: "Caribbean")))
        let result = MapUIReducer.reduce(
            state: state,
            action: .drillDownToArea("Cozumel", region: nil),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .area(regionId: "Caribbean", areaId: "Cozumel"))
    }

    func testDrillDownToAreaFromWorld_NoOp() {
        let state = MapUIMode.explore(ExploreContext(hierarchyLevel: .world))
        let result = MapUIReducer.reduce(
            state: state,
            action: .drillDownToArea("Cozumel", region: nil),
            currentFilters: defaultFilters
        )

        // Should remain unchanged - can't drill to area from world
        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .world)
    }

    func testNavigateUp_FromArea() {
        let state = MapUIMode.explore(ExploreContext(
            hierarchyLevel: .area(regionId: "Caribbean", areaId: "Cozumel")
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .navigateUp,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
    }

    func testNavigateUp_FromRegion() {
        let state = MapUIMode.explore(ExploreContext(hierarchyLevel: .region(countryId: nil, regionId: "Caribbean")))
        let result = MapUIReducer.reduce(
            state: state,
            action: .navigateUp,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .world)
    }

    func testNavigateUp_FromWorld_NoOp() {
        let state = MapUIMode.explore(ExploreContext(hierarchyLevel: .world))
        let result = MapUIReducer.reduce(
            state: state,
            action: .navigateUp,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .world)
    }

    func testResetToWorld() {
        let state = MapUIMode.explore(ExploreContext(
            hierarchyLevel: .area(regionId: "Caribbean", areaId: "Cozumel")
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .resetToWorld,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .world)
    }

    // MARK: - Filter Lens Tests

    func testApplyFilterLens() {
        let state = MapUIMode.explore(ExploreContext())
        let result = MapUIReducer.reduce(
            state: state,
            action: .applyFilterLens(.saved),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.filterLens, .saved)
    }

    func testClearFilterLens() {
        let state = MapUIMode.explore(ExploreContext(filterLens: .saved))
        let result = MapUIReducer.reduce(
            state: state,
            action: .clearFilterLens,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertNil(ctx.filterLens)
    }

    // MARK: - Site Inspection Tests

    func testOpenSiteInspection() {
        let exploreCtx = ExploreContext(
            hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"),
            filterLens: .saved
        )
        let state = MapUIMode.explore(exploreCtx)
        let result = MapUIReducer.reduce(
            state: state,
            action: .openSiteInspection("site-123"),
            currentFilters: defaultFilters
        )

        guard case .inspectSite(let ctx) = result else {
            XCTFail("Expected inspect mode")
            return
        }
        XCTAssertEqual(ctx.siteId, "site-123")
        XCTAssertEqual(ctx.returnContext.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
        XCTAssertEqual(ctx.returnContext.filterLens, .saved)
    }

    func testCloseSiteInspection() {
        let returnContext = ExploreContext(
            hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"),
            filterLens: .logged
        )
        let state = MapUIMode.inspectSite(SiteInspectionContext(
            siteId: "site-123",
            returnContext: returnContext
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
        XCTAssertEqual(ctx.filterLens, .logged)
    }

    // MARK: - Filter Mode Tests

    func testOpenFilter() {
        let exploreCtx = ExploreContext(hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"))
        let state = MapUIMode.explore(exploreCtx)
        let result = MapUIReducer.reduce(
            state: state,
            action: .openFilter,
            currentFilters: defaultFilters
        )

        guard case .filter(let ctx) = result else {
            XCTFail("Expected filter mode")
            return
        }
        XCTAssertEqual(ctx.returnContext.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
        XCTAssertEqual(ctx.exploreFilters, defaultFilters)
    }

    func testCloseFilterApply() {
        let returnContext = ExploreContext(hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"))
        let state = MapUIMode.filter(FilterContext(
            exploreFilters: defaultFilters,
            returnContext: returnContext
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .closeFilter(apply: true),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
    }

    func testCloseFilterCancel() {
        let returnContext = ExploreContext(hierarchyLevel: .world)
        let state = MapUIMode.filter(FilterContext(
            exploreFilters: defaultFilters,
            returnContext: returnContext
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .closeFilter(apply: false),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .world)
    }

    // MARK: - Search Mode Tests

    func testOpenSearch() {
        let exploreCtx = ExploreContext(filterLens: .saved)
        let state = MapUIMode.explore(exploreCtx)
        let result = MapUIReducer.reduce(
            state: state,
            action: .openSearch,
            currentFilters: defaultFilters
        )

        guard case .search(let ctx) = result else {
            XCTFail("Expected search mode")
            return
        }
        XCTAssertEqual(ctx.query, "")
        XCTAssertEqual(ctx.returnContext.filterLens, .saved)
    }

    func testCloseSearchWithSelection() {
        let returnContext = ExploreContext(hierarchyLevel: .world)
        let state = MapUIMode.search(SearchContext(
            query: "reef",
            returnContext: returnContext
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .closeSearch(selectedSite: "site-456"),
            currentFilters: defaultFilters
        )

        guard case .inspectSite(let ctx) = result else {
            XCTFail("Expected inspect mode")
            return
        }
        XCTAssertEqual(ctx.siteId, "site-456")
        XCTAssertEqual(ctx.returnContext.hierarchyLevel, .world)
        XCTAssertEqual(ctx.returnSearchContext?.query, "reef")
        guard case .some(.search(let returnSurfaceContext)) = ctx.returnSurface else {
            XCTFail("Expected search return surface")
            return
        }
        XCTAssertEqual(returnSurfaceContext.query, "reef")
    }

    func testCloseSearchWithoutSelection() {
        let returnContext = ExploreContext(
            hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"),
            filterLens: .logged
        )
        let state = MapUIMode.search(SearchContext(
            query: "reef",
            returnContext: returnContext
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .closeSearch(selectedSite: nil),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
        XCTAssertEqual(ctx.filterLens, .logged)
    }

    // MARK: - Invalid Transition Tests

    func testInvalidTransition_InspectToFilter() {
        let state = MapUIMode.inspectSite(SiteInspectionContext(
            siteId: "site-123",
            returnContext: ExploreContext()
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .openFilter,
            currentFilters: defaultFilters
        )

        // Should remain unchanged - can't open filter from inspect mode
        guard case .inspectSite(let ctx) = result else {
            XCTFail("Expected inspect mode unchanged")
            return
        }
        XCTAssertEqual(ctx.siteId, "site-123")
    }

    func testFilterToInspectStoresReturnSurface() {
        let state = MapUIMode.filter(FilterContext(
            exploreFilters: defaultFilters,
            returnContext: ExploreContext(hierarchyLevel: .country("ID"))
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .openSiteInspection("site-123"),
            currentFilters: defaultFilters
        )

        guard case .inspectSite(let inspection) = result else {
            XCTFail("Expected inspect mode")
            return
        }
        guard case .some(.filter(let filterSurface)) = inspection.returnSurface else {
            XCTFail("Expected filter return surface")
            return
        }
        XCTAssertEqual(filterSurface.returnContext.hierarchyLevel, .country("ID"))
    }

    // MARK: - Preview Tests

    func testShowPreview() {
        let state = MapUIMode.explore(ExploreContext())
        let result = MapUIReducer.reduce(
            state: state,
            action: .showPreview("site-789"),
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(ctx.previewingSite, "site-789")
    }

    func testDismissPreview() {
        let state = MapUIMode.explore(ExploreContext(previewingSite: "site-789"))
        let result = MapUIReducer.reduce(
            state: state,
            action: .dismissPreview,
            currentFilters: defaultFilters
        )

        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertNil(ctx.previewingSite)
    }

    func testPromotePreviewToInspect() {
        let state = MapUIMode.explore(ExploreContext(
            hierarchyLevel: .region(countryId: nil, regionId: "Caribbean"),
            previewingSite: "site-789"
        ))
        let result = MapUIReducer.reduce(
            state: state,
            action: .promotePreviewToInspect,
            currentFilters: defaultFilters
        )

        guard case .inspectSite(let ctx) = result else {
            XCTFail("Expected inspect mode")
            return
        }
        XCTAssertEqual(ctx.siteId, "site-789")
        XCTAssertEqual(ctx.returnContext.hierarchyLevel, .region(countryId: nil, regionId: "Caribbean"))
        XCTAssertNil(ctx.returnContext.previewingSite)
    }

    func testPromotePreviewToInspect_NoPreview_NoOp() {
        let state = MapUIMode.explore(ExploreContext())
        let result = MapUIReducer.reduce(
            state: state,
            action: .promotePreviewToInspect,
            currentFilters: defaultFilters
        )

        // Should remain unchanged - no preview to promote
        guard case .explore(let ctx) = result else {
            XCTFail("Expected explore mode unchanged")
            return
        }
        XCTAssertNil(ctx.previewingSite)
    }

    func testClusterSiteInspectionCloseReturnsToSiteStack() {
        let exploreCtx = ExploreContext(hierarchyLevel: .region(countryId: "ID", regionId: "coral-triangle"))
        let clusterCtx = ClusterExpandContext(
            clusterCenter: CLLocationCoordinate2D(latitude: -0.5, longitude: 130.5),
            siteCount: 3,
            memberSiteIds: ["site-a", "site-b", "site-c"],
            expansionZoomLevel: 9,
            returnContext: exploreCtx
        )
        let clusterState = MapUIReducer.reduce(
            state: .explore(exploreCtx),
            action: .openClusterExpand(clusterCtx),
            currentFilters: defaultFilters
        )
        let inspectState = MapUIReducer.reduce(
            state: clusterState,
            action: .openSiteInspection("site-b"),
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: inspectState,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )

        guard case .clusterExpand(let returnedCluster) = result else {
            XCTFail("Expected to return to cluster expand")
            return
        }
        XCTAssertEqual(returnedCluster.memberSiteIds, ["site-a", "site-b", "site-c"])
        XCTAssertEqual(returnedCluster.returnContext.hierarchyLevel, exploreCtx.hierarchyLevel)
    }

    func testFilterCancelReturnsToPreviousExploreContext() {
        let exploreCtx = ExploreContext(
            hierarchyLevel: .country("ID"),
            filterLens: .saved,
            speciesFilter: "manta-ray"
        )
        let filterState = MapUIReducer.reduce(
            state: .explore(exploreCtx),
            action: .openFilter,
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: filterState,
            action: .closeFilter(apply: false),
            currentFilters: defaultFilters
        )

        guard case .explore(let returnedContext) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(returnedContext, exploreCtx)
    }

    func testSearchCloseReturnsToPreviousExploreContext() {
        let exploreCtx = ExploreContext(
            hierarchyLevel: .area(regionId: "coral-triangle", areaId: "raja-ampat"),
            filterLens: .logged
        )
        let searchState = MapUIReducer.reduce(
            state: .explore(exploreCtx),
            action: .openSearch,
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: searchState,
            action: .closeSearch(selectedSite: nil),
            currentFilters: defaultFilters
        )

        guard case .explore(let returnedContext) = result else {
            XCTFail("Expected explore mode")
            return
        }
        XCTAssertEqual(returnedContext, exploreCtx)
    }

    func testSearchInspectCloseReturnsToSearchSurface() {
        let exploreCtx = ExploreContext(hierarchyLevel: .region(countryId: "ID", regionId: "coral-triangle"))
        let searchCtx = SearchContext(query: "indo", returnContext: exploreCtx)
        let inspectState = MapUIReducer.reduce(
            state: .search(searchCtx),
            action: .openSiteInspection("site-42"),
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: inspectState,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )

        guard case .search(let returnedSearchContext) = result else {
            XCTFail("Expected to return to search")
            return
        }
        XCTAssertEqual(returnedSearchContext, searchCtx)
    }

    func testFilterInspectCloseReturnsToFilterSurface() {
        let exploreCtx = ExploreContext(hierarchyLevel: .country("ID"), filterLens: .saved)
        let filterCtx = FilterContext(exploreFilters: defaultFilters, returnContext: exploreCtx)
        let inspectState = MapUIReducer.reduce(
            state: .filter(filterCtx),
            action: .openSiteInspection("site-42"),
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: inspectState,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )

        guard case .filter(let returnedFilterContext) = result else {
            XCTFail("Expected to return to filter")
            return
        }
        XCTAssertEqual(returnedFilterContext.returnContext, exploreCtx)
        XCTAssertEqual(returnedFilterContext.exploreFilters, defaultFilters)
    }

    func testNearMeInspectCloseReturnsToNearMeSurface() {
        let nearMeCtx = NearMeContext(
            latitude: -0.5,
            longitude: 130.5,
            returnContext: ExploreContext(hierarchyLevel: .world)
        )
        let inspectState = MapUIReducer.reduce(
            state: .nearMe(nearMeCtx),
            action: .openSiteInspection("site-42"),
            currentFilters: defaultFilters
        )
        let result = MapUIReducer.reduce(
            state: inspectState,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )

        guard case .nearMe(let returnedNearMeContext) = result else {
            XCTFail("Expected to return to near me")
            return
        }
        XCTAssertEqual(returnedNearMeContext, nearMeCtx)
    }

    func testOpenSiteInspectionWithReturnSurfaceFromExploreReturnsToSearchOnClose() {
        let exploreCtx = ExploreContext(hierarchyLevel: .world)
        let searchCtx = SearchContext(query: "indonesia", returnContext: exploreCtx)
        let inspectState = MapUIReducer.reduce(
            state: .explore(exploreCtx),
            action: .openSiteInspectionWithReturnSurface(
                siteId: "site-777",
                returnSurface: .search(searchCtx)
            ),
            currentFilters: defaultFilters
        )

        guard case .inspectSite(let inspectionContext) = inspectState else {
            XCTFail("Expected inspect mode")
            return
        }
        guard case .some(.search(let storedSearchContext)) = inspectionContext.returnSurface else {
            XCTFail("Expected stored search return surface")
            return
        }
        XCTAssertEqual(storedSearchContext, searchCtx)

        let result = MapUIReducer.reduce(
            state: inspectState,
            action: .closeSiteInspection,
            currentFilters: defaultFilters
        )
        guard case .search(let returnedSearchContext) = result else {
            XCTFail("Expected to return to search")
            return
        }
        XCTAssertEqual(returnedSearchContext, searchCtx)
    }
}
