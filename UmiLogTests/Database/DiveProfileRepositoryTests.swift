import XCTest
@testable import UmiDB

final class DiveProfileRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var siteRepository: SiteRepository!
    private var diveRepository: DiveRepository!
    private var profileRepository: DiveProfileRepository!
    private var testSite: DiveSite!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        siteRepository = SiteRepository(database: database)
        diveRepository = DiveRepository(database: database)
        profileRepository = DiveProfileRepository(database: database)

        testSite = TestDatabase.makeSite(id: "site-1")
        try siteRepository.create(testSite)
    }

    override func tearDownWithError() throws {
        database = nil
        siteRepository = nil
        diveRepository = nil
        profileRepository = nil
        testSite = nil
    }

    func testUpsertAndFetchByDive() throws {
        let dive = TestDatabase.makeDive(id: "dive-1", siteId: testSite.id)
        try diveRepository.create(dive)

        let samples = [
            DiveProfileSample(time: 0, depth: 0),
            DiveProfileSample(time: 60, depth: 12.3),
            DiveProfileSample(time: 120, depth: 18.5)
        ]
        let sampleBlob = try DiveProfile.encodeSamples(samples)

        let profile = DiveProfile(
            diveId: dive.id,
            samples: sampleBlob,
            sampleIntervalSec: 60,
            sampleCount: samples.count,
            source: .shearwater,
            computerSerial: "A12345",
            computerModel: "Perdix AI"
        )

        try profileRepository.upsert(profile)
        let fetched = try profileRepository.fetchByDive(dive.id)

        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.sampleCount, 3)
        XCTAssertEqual(fetched?.source, .shearwater)

        let decoded = try DiveProfile.decodeSamples(from: fetched!.samples)
        XCTAssertEqual(decoded.count, 3)
        XCTAssertEqual(decoded[1].depth, 12.3, accuracy: 0.001)
    }
}
