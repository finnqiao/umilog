import XCTest
import GRDB
@testable import UmiDB

final class DiveRepositoryTests: XCTestCase {
    var database: AppDatabase!
    var diveRepository: DiveRepository!
    var siteRepository: SiteRepository!
    var testSite: DiveSite!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        diveRepository = DiveRepository(database: database)
        siteRepository = SiteRepository(database: database)

        // Create a test site for dive logs
        testSite = TestDatabase.makeSite(id: "test-site", name: "Test Site")
        try siteRepository.create(testSite)
    }

    override func tearDownWithError() throws {
        database = nil
        diveRepository = nil
        siteRepository = nil
        testSite = nil
    }

    // MARK: - Create Tests

    func testCreate_insertsNewDive() throws {
        let dive = TestDatabase.makeDive(siteId: testSite.id)

        try diveRepository.create(dive)

        let fetched = try diveRepository.fetch(id: dive.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.siteId, testSite.id)
    }

    // MARK: - Fetch Tests

    func testFetchAll_returnsAllDives() throws {
        try diveRepository.create(TestDatabase.makeDive(id: "1", siteId: testSite.id))
        try diveRepository.create(TestDatabase.makeDive(id: "2", siteId: testSite.id))

        let allDives = try diveRepository.fetchAll()
        XCTAssertEqual(allDives.count, 2)
    }

    func testFetchRecent_limitsResults() throws {
        for i in 1...10 {
            try diveRepository.create(TestDatabase.makeDive(
                id: "\(i)",
                siteId: testSite.id,
                date: Date().addingTimeInterval(TimeInterval(-i * 86400))
            ))
        }

        let recent = try diveRepository.fetchRecent(limit: 5)
        XCTAssertEqual(recent.count, 5)
    }

    func testFetchBySite_filtersCorrectly() throws {
        // Create another site
        let site2 = TestDatabase.makeSite(id: "site-2", name: "Site 2")
        try siteRepository.create(site2)

        // Create dives for both sites
        try diveRepository.create(TestDatabase.makeDive(id: "1", siteId: testSite.id))
        try diveRepository.create(TestDatabase.makeDive(id: "2", siteId: testSite.id))
        try diveRepository.create(TestDatabase.makeDive(id: "3", siteId: site2.id))

        let divesAtSite1 = try diveRepository.fetchBySite(siteId: testSite.id)
        XCTAssertEqual(divesAtSite1.count, 2)

        let divesAtSite2 = try diveRepository.fetchBySite(siteId: site2.id)
        XCTAssertEqual(divesAtSite2.count, 1)
    }

    // MARK: - Delete Tests

    func testDelete_removesDive() throws {
        let dive = TestDatabase.makeDive(siteId: testSite.id)
        try diveRepository.create(dive)

        try diveRepository.delete(id: dive.id)

        let fetched = try diveRepository.fetch(id: dive.id)
        XCTAssertNil(fetched)
    }

    // MARK: - Stats Tests

    func testCalculateStats_computesCorrectly() throws {
        try diveRepository.create(TestDatabase.makeDive(id: "1", siteId: testSite.id, maxDepth: 20.0, bottomTime: 40))
        try diveRepository.create(TestDatabase.makeDive(id: "2", siteId: testSite.id, maxDepth: 30.0, bottomTime: 50))
        try diveRepository.create(TestDatabase.makeDive(id: "3", siteId: testSite.id, maxDepth: 25.0, bottomTime: 45))

        let stats = try diveRepository.calculateStats()

        XCTAssertEqual(stats.totalDives, 3)
        XCTAssertEqual(stats.totalBottomTime, 135)  // 40 + 50 + 45
        XCTAssertEqual(stats.maxDepth, 30.0)
    }

    func testFetchHeatmapPoints_includesSiteAndGPSOnlyDives() throws {
        try diveRepository.create(TestDatabase.makeDive(id: "site-1", siteId: testSite.id))
        try diveRepository.create(TestDatabase.makeDive(id: "site-2", siteId: testSite.id))

        let gpsDive = DiveLog(
            id: "gps-1",
            siteId: nil,
            pendingLatitude: 10.1234,
            pendingLongitude: -20.5678,
            date: Date(),
            startTime: Date(),
            endTime: Date().addingTimeInterval(2400),
            maxDepth: 18,
            averageDepth: 12,
            bottomTime: 40,
            startPressure: 200,
            endPressure: 70,
            temperature: 26,
            visibility: 15,
            current: .none,
            conditions: .good,
            notes: ""
        )
        try diveRepository.create(gpsDive)

        let points = try diveRepository.fetchHeatmapPoints()
        let sitePoint = points.first { $0.siteName == testSite.name }
        let gpsPoint = points.first {
            abs($0.latitude - 10.1234) < 0.0001 && abs($0.longitude + 20.5678) < 0.0001
        }

        XCTAssertEqual(sitePoint?.diveCount, 2)
        XCTAssertEqual(gpsPoint?.diveCount, 1)
    }

    // MARK: - Date Range Tests

    func testFetchInDateRange_filtersCorrectly() throws {
        let now = Date()
        let yesterday = now.addingTimeInterval(-86400)
        let lastWeek = now.addingTimeInterval(-7 * 86400)
        let lastMonth = now.addingTimeInterval(-30 * 86400)

        try diveRepository.create(TestDatabase.makeDive(id: "1", siteId: testSite.id, date: now))
        try diveRepository.create(TestDatabase.makeDive(id: "2", siteId: testSite.id, date: yesterday))
        try diveRepository.create(TestDatabase.makeDive(id: "3", siteId: testSite.id, date: lastWeek))
        try diveRepository.create(TestDatabase.makeDive(id: "4", siteId: testSite.id, date: lastMonth))

        // Fetch dives from last 3 days
        let recentDives = try fetchDivesInDateRange(
            from: now.addingTimeInterval(-3 * 86400),
            to: now
        )
        XCTAssertEqual(recentDives.count, 2)  // today and yesterday
    }
}

// MARK: - Test Helper Extensions

extension DiveRepositoryTests {
    /// Helper to fetch dives within a date range using the test database
    func fetchDivesInDateRange(from: Date, to: Date) throws -> [DiveLog] {
        try database.read { db in
            try DiveLog
                .filter(Column("date") >= from)
                .filter(Column("date") <= to)
                .order(Column("date").desc)
                .fetchAll(db)
        }
    }
}
