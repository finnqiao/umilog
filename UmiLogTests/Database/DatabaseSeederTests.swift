import XCTest
@testable import UmiDB

final class DatabaseSeederTests: XCTestCase {
    var database: AppDatabase!
    var siteRepository: SiteRepository!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        siteRepository = SiteRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        siteRepository = nil
    }

    func testReconcileCuratedSeedDataRestoresIndonesiaAndPreservesMappedUserState() throws {
        try database.write { db in
            try Country(id: "ID", name: "Indonesia", continent: "Asia").insert(db)
        }
        try siteRepository.create(
            TestDatabase.makeSite(
                id: "osm_node_5409736127",
                name: "Batu Bolong Legacy",
                latitude: -8.537,
                longitude: 119.614,
                region: "Legacy Indonesia",
                countryId: "ID"
            )
        )
        try siteRepository.toggleWishlist(siteId: "osm_node_5409736127")
        try siteRepository.incrementVisitedCount(siteId: "osm_node_5409736127")
        try siteRepository.incrementVisitedCount(siteId: "osm_node_5409736127")
        try siteRepository.incrementVisitedCount(siteId: "osm_node_5409736127")

        let before = try DatabaseSeeder.auditCuratedSeedData(database: database)
        XCTAssertTrue(before.needsCuratedRefresh)

        let after = try DatabaseSeeder.reconcileCuratedSeedDataIfNeeded(database: database, force: true)

        XCTAssertEqual(after.expectedCuratedSiteCount, after.actualCuratedSiteCount)
        XCTAssertEqual(after.expectedIndonesiaSiteCount, after.actualIndonesiaSiteCount)
        XCTAssertGreaterThanOrEqual(after.actualIndonesiaSiteCount, 20)
        XCTAssertEqual(after.countryLinkIssueCount, 0)
        XCTAssertEqual(after.regionLinkIssueCount, 0)
        XCTAssertEqual(after.generatedParityMismatchCount, 0)

        let curated = try siteRepository.fetch(id: "curated_komodo-national-park_batu-bolong")
        XCTAssertEqual(curated?.wishlist, true)
        XCTAssertEqual(curated?.visitedCount, 3)
    }

    func testAuditCuratedSeedDataDetectsCountryRegionAndParityIssues() throws {
        try database.write { db in
            try Country(id: "US", name: "United States", continent: "North America").insert(db)
            try Region(id: "legacy-region", name: "Legacy Region", countryId: "US").insert(db)
        }

        try siteRepository.create(
            TestDatabase.makeSite(
                id: "curated_komodo-national-park_batu-bolong",
                name: "Batu Bolong (Legacy)",
                latitude: 0,
                longitude: 0,
                region: "Legacy Region",
                countryId: "US",
                regionId: "legacy-region"
            )
        )

        let summary = try DatabaseSeeder.auditCuratedSeedData(database: database)

        XCTAssertGreaterThanOrEqual(summary.countryLinkIssueCount, 1)
        XCTAssertGreaterThanOrEqual(summary.regionLinkIssueCount, 1)
        XCTAssertGreaterThanOrEqual(summary.generatedParityMismatchCount, 1)
    }
}
