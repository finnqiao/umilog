import XCTest
@testable import UmiDB

final class DiveGearRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var siteRepository: SiteRepository!
    private var diveRepository: DiveRepository!
    private var gearRepository: GearRepository!
    private var diveGearRepository: DiveGearRepository!
    private var testSite: DiveSite!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        siteRepository = SiteRepository(database: database)
        diveRepository = DiveRepository(database: database)
        gearRepository = GearRepository(database: database)
        diveGearRepository = DiveGearRepository(database: database)

        testSite = TestDatabase.makeSite(id: "site-1")
        try siteRepository.create(testSite)
    }

    override func tearDownWithError() throws {
        database = nil
        siteRepository = nil
        diveRepository = nil
        gearRepository = nil
        diveGearRepository = nil
        testSite = nil
    }

    func testSetGearForDiveCreatesLinksAndUpdatesCounts() throws {
        let dive = TestDatabase.makeDive(id: "dive-1", siteId: testSite.id)
        try diveRepository.create(dive)

        let regulator = TestDatabase.makeGearItem(id: "gear-reg", category: .regulator)
        let bcd = TestDatabase.makeGearItem(id: "gear-bcd", category: .bcd)
        try gearRepository.upsert(regulator)
        try gearRepository.upsert(bcd)

        try diveGearRepository.setGear(forDive: dive.id, gearIds: [regulator.id, bcd.id, regulator.id])

        let links = try diveGearRepository.fetchLinks(forDive: dive.id)
        XCTAssertEqual(links.count, 2)

        let refreshedReg = try gearRepository.fetch(id: regulator.id)
        let refreshedBCD = try gearRepository.fetch(id: bcd.id)
        XCTAssertEqual(refreshedReg?.totalDiveCount, 1)
        XCTAssertEqual(refreshedBCD?.totalDiveCount, 1)
    }
}
