import XCTest
@testable import UmiDB

final class SightingPhotoRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var siteRepository: SiteRepository!
    private var diveRepository: DiveRepository!
    private var sightingsRepository: SightingsRepository!
    private var photoRepository: SightingPhotoRepository!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        siteRepository = SiteRepository(database: database)
        diveRepository = DiveRepository(database: database)
        sightingsRepository = SightingsRepository(database: database)
        photoRepository = SightingPhotoRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        siteRepository = nil
        diveRepository = nil
        sightingsRepository = nil
        photoRepository = nil
    }

    func testCreateAndFetchBySighting() throws {
        let context = try makeSightingContext()
        let photo = SightingPhoto(
            sightingId: context.sighting.id,
            filename: "sighting_photos/\(context.sighting.id)/a.jpg",
            thumbnailFilename: "sighting_photos/\(context.sighting.id)/a_thumb.jpg",
            width: 1200,
            height: 800,
            sortOrder: 0
        )

        try photoRepository.create(photo)
        let fetched = try photoRepository.fetchBySighting(context.sighting.id)

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.filename, photo.filename)
    }

    func testFetchByDiveReturnsPhotosAcrossSightings() throws {
        let first = try makeSightingContext(sightingId: "s-1")
        let second = try makeSightingContext(sightingId: "s-2")

        try photoRepository.createMany([
            SightingPhoto(
                id: "p-1",
                sightingId: first.sighting.id,
                filename: "sighting_photos/\(first.sighting.id)/1.jpg",
                thumbnailFilename: "sighting_photos/\(first.sighting.id)/1_thumb.jpg",
                width: 800,
                height: 600,
                sortOrder: 0
            ),
            SightingPhoto(
                id: "p-2",
                sightingId: second.sighting.id,
                filename: "sighting_photos/\(second.sighting.id)/1.jpg",
                thumbnailFilename: "sighting_photos/\(second.sighting.id)/1_thumb.jpg",
                width: 800,
                height: 600,
                sortOrder: 0
            )
        ])

        let firstDivePhotos = try photoRepository.fetchByDive(first.dive.id)
        let secondDivePhotos = try photoRepository.fetchByDive(second.dive.id)

        XCTAssertEqual(firstDivePhotos.count, 1)
        XCTAssertEqual(secondDivePhotos.count, 1)
        XCTAssertNotEqual(firstDivePhotos.first?.sightingId, secondDivePhotos.first?.sightingId)
    }

    private func makeSightingContext(sightingId: String = UUID().uuidString) throws -> (dive: DiveLog, sighting: WildlifeSighting) {
        let site = TestDatabase.makeSite(id: UUID().uuidString)
        try siteRepository.create(site)

        let species = TestDatabase.makeSpecies(id: UUID().uuidString)
        try database.write { db in
            try species.insert(db)
        }

        let dive = TestDatabase.makeDive(id: UUID().uuidString, siteId: site.id)
        try diveRepository.create(dive)

        let sighting = TestDatabase.makeSighting(id: sightingId, diveId: dive.id, speciesId: species.id)
        try sightingsRepository.create(sighting)

        return (dive, sighting)
    }
}
