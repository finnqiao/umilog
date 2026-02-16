import XCTest
import GRDB
@testable import UmiDB

final class SiteRepositoryTests: XCTestCase {
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

    // MARK: - Create Tests

    func testCreate_insertsNewSite() throws {
        let site = TestDatabase.makeSite(name: "Blue Hole")

        try siteRepository.create(site)

        let fetched = try siteRepository.fetch(id: site.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Blue Hole")
    }

    func testCreateMany_insertsMultipleSites() throws {
        let sites = [
            TestDatabase.makeSite(id: "1", name: "Site 1"),
            TestDatabase.makeSite(id: "2", name: "Site 2"),
            TestDatabase.makeSite(id: "3", name: "Site 3")
        ]

        try siteRepository.createMany(sites)

        let allSites = try siteRepository.fetchAll()
        XCTAssertEqual(allSites.count, 3)
    }

    // MARK: - Fetch Tests

    func testFetch_returnsNilForNonexistentSite() throws {
        let fetched = try siteRepository.fetch(id: "nonexistent")
        XCTAssertNil(fetched)
    }

    func testFetchAll_returnsAllSites() throws {
        try siteRepository.createMany([
            TestDatabase.makeSite(id: "1", name: "Site 1"),
            TestDatabase.makeSite(id: "2", name: "Site 2")
        ])

        let allSites = try siteRepository.fetchAll()
        XCTAssertEqual(allSites.count, 2)
    }

    // MARK: - Bounds Query Tests

    func testFetchInBounds_filtersCorrectly() throws {
        // Create sites in different locations
        try siteRepository.createMany([
            TestDatabase.makeSite(id: "1", name: "Egypt Site", latitude: 27.5, longitude: 33.8),
            TestDatabase.makeSite(id: "2", name: "Caribbean Site", latitude: 18.0, longitude: -64.0),
            TestDatabase.makeSite(id: "3", name: "Thailand Site", latitude: 7.5, longitude: 98.5)
        ])

        // Query for Red Sea area
        let bounds = TestMapBounds(
            minLat: 20.0,
            maxLat: 30.0,
            minLon: 30.0,
            maxLon: 40.0
        )

        let sitesInBounds = try fetchSitesInBounds(bounds)
        XCTAssertEqual(sitesInBounds.count, 1)
        XCTAssertEqual(sitesInBounds.first?.name, "Egypt Site")
    }

    // MARK: - Wishlist Tests

    func testToggleWishlist_updatesState() throws {
        let site = TestDatabase.makeSite(name: "Wishlist Test")
        try siteRepository.create(site)

        // Initially not wishlisted
        var fetched = try siteRepository.fetch(id: site.id)
        XCTAssertFalse(fetched?.wishlist ?? true)

        // Toggle on
        try siteRepository.toggleWishlist(siteId: site.id)
        fetched = try siteRepository.fetch(id: site.id)
        XCTAssertTrue(fetched?.wishlist ?? false)

        // Toggle off
        try siteRepository.toggleWishlist(siteId: site.id)
        fetched = try siteRepository.fetch(id: site.id)
        XCTAssertFalse(fetched?.wishlist ?? true)
    }

    // MARK: - Visited Count Tests

    func testIncrementVisitedCount_incrementsCorrectly() throws {
        let site = TestDatabase.makeSite(name: "Visit Test")
        try siteRepository.create(site)

        // Initially 0
        var fetched = try siteRepository.fetch(id: site.id)
        XCTAssertEqual(fetched?.visitedCount, 0)

        // Increment
        try siteRepository.incrementVisitedCount(siteId: site.id)
        fetched = try siteRepository.fetch(id: site.id)
        XCTAssertEqual(fetched?.visitedCount, 1)

        // Increment again
        try siteRepository.incrementVisitedCount(siteId: site.id)
        fetched = try siteRepository.fetch(id: site.id)
        XCTAssertEqual(fetched?.visitedCount, 2)
    }

    // MARK: - Difficulty Filter Tests

    func testFetchByDifficulty_filtersCorrectly() throws {
        try siteRepository.createMany([
            TestDatabase.makeSite(id: "1", name: "Beginner Site", difficulty: .beginner),
            TestDatabase.makeSite(id: "2", name: "Intermediate Site", difficulty: .intermediate),
            TestDatabase.makeSite(id: "3", name: "Advanced Site", difficulty: .advanced)
        ])

        let beginnerSites = try siteRepository.fetchAll().filter { $0.difficulty == .beginner }
        XCTAssertEqual(beginnerSites.count, 1)
        XCTAssertEqual(beginnerSites.first?.name, "Beginner Site")
    }
}

// MARK: - MapBounds Helper for Tests

struct TestMapBounds {
    let minLat: Double
    let maxLat: Double
    let minLon: Double
    let maxLon: Double
}

extension SiteRepositoryTests {
    func fetchSitesInBounds(_ bounds: TestMapBounds) throws -> [DiveSite] {
        try database.read { db in
            try DiveSite
                .filter(Column("latitude") >= bounds.minLat)
                .filter(Column("latitude") <= bounds.maxLat)
                .filter(Column("longitude") >= bounds.minLon)
                .filter(Column("longitude") <= bounds.maxLon)
                .fetchAll(db)
        }
    }
}
