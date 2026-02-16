import XCTest
@testable import UmiDB

final class SpeciesRepositoryTests: XCTestCase {
    var database: AppDatabase!
    var speciesRepository: SpeciesRepository!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        speciesRepository = SpeciesRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        speciesRepository = nil
    }

    // MARK: - Create Tests

    func testCreate_insertsNewSpecies() throws {
        let species = TestDatabase.makeSpecies(name: "Clownfish")

        try speciesRepository.create(species)

        let fetched = try speciesRepository.fetch(id: species.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.name, "Clownfish")
    }

    func testCreateMany_insertsMultipleSpecies() throws {
        let speciesList = [
            TestDatabase.makeSpecies(id: "1", name: "Clownfish"),
            TestDatabase.makeSpecies(id: "2", name: "Manta Ray"),
            TestDatabase.makeSpecies(id: "3", name: "Sea Turtle")
        ]

        try speciesRepository.createMany(speciesList)

        let allSpecies = try speciesRepository.fetchAll()
        XCTAssertEqual(allSpecies.count, 3)
    }

    // MARK: - Fetch Tests

    func testFetch_returnsNilForNonexistentSpecies() throws {
        let fetched = try speciesRepository.fetch(id: "nonexistent")
        XCTAssertNil(fetched)
    }

    func testFetchAll_returnsAllSpecies() throws {
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "1", name: "Species 1"),
            TestDatabase.makeSpecies(id: "2", name: "Species 2")
        ])

        let allSpecies = try speciesRepository.fetchAll()
        XCTAssertEqual(allSpecies.count, 2)
    }

    // MARK: - Search Tests

    func testSearch_findsSpeciesByName() throws {
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "1", name: "Clownfish"),
            TestDatabase.makeSpecies(id: "2", name: "Manta Ray"),
            TestDatabase.makeSpecies(id: "3", name: "Reef Shark")
        ])

        let results = try speciesRepository.search("Clown")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "Clownfish")
    }

    func testSearch_emptyQuery_returnsAll() throws {
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "1", name: "Clownfish"),
            TestDatabase.makeSpecies(id: "2", name: "Manta Ray")
        ])

        let results = try speciesRepository.search("")
        XCTAssertEqual(results.count, 2)
    }

    // MARK: - FetchForSite Tests

    func testFetchForSite_returnsLinkedSpecies() throws {
        // Create species
        let clownfish = TestDatabase.makeSpecies(id: "sp1", name: "Clownfish")
        let mantaRay = TestDatabase.makeSpecies(id: "sp2", name: "Manta Ray")
        let shark = TestDatabase.makeSpecies(id: "sp3", name: "Reef Shark")
        try speciesRepository.createMany([clownfish, mantaRay, shark])

        // Create site
        let siteRepo = SiteRepository(database: database)
        let site = TestDatabase.makeSite(id: "site1", name: "Blue Hole")
        try siteRepo.create(site)

        // Create links - only clownfish and manta ray at this site
        try speciesRepository.createSiteLinks([
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp1", likelihood: .common),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp2", likelihood: .occasional)
        ])

        // Fetch species at site
        let speciesAtSite = try speciesRepository.fetchForSite("site1")

        XCTAssertEqual(speciesAtSite.count, 2)
        // Should be ordered by likelihood (common first)
        XCTAssertEqual(speciesAtSite[0].name, "Clownfish")
        XCTAssertEqual(speciesAtSite[1].name, "Manta Ray")
    }

    func testFetchForSite_withMultipleLinks_returnsAll() throws {
        // Create species
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "sp1", name: "Species 1"),
            TestDatabase.makeSpecies(id: "sp2", name: "Species 2"),
            TestDatabase.makeSpecies(id: "sp3", name: "Species 3"),
            TestDatabase.makeSpecies(id: "sp4", name: "Species 4"),
            TestDatabase.makeSpecies(id: "sp5", name: "Species 5")
        ])

        // Create site
        let siteRepo = SiteRepository(database: database)
        let site = TestDatabase.makeSite(id: "site1", name: "Test Site")
        try siteRepo.create(site)

        // Link all species to site
        try speciesRepository.createSiteLinks([
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp1"),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp2"),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp3"),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp4"),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp5")
        ])

        // Fetch all species at site
        let speciesAtSite = try speciesRepository.fetchForSite("site1")

        XCTAssertEqual(speciesAtSite.count, 5)
    }

    func testFetchForSite_ordersbyLikelihood() throws {
        // Create species
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "sp1", name: "Rare Species"),
            TestDatabase.makeSpecies(id: "sp2", name: "Common Species"),
            TestDatabase.makeSpecies(id: "sp3", name: "Occasional Species")
        ])

        // Create site
        let siteRepo = SiteRepository(database: database)
        let site = TestDatabase.makeSite(id: "site1", name: "Test Site")
        try siteRepo.create(site)

        // Link with different likelihoods
        try speciesRepository.createSiteLinks([
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp1", likelihood: .rare),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp2", likelihood: .common),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp3", likelihood: .occasional)
        ])

        let speciesAtSite = try speciesRepository.fetchForSite("site1")

        // Order should be: common, occasional, rare
        XCTAssertEqual(speciesAtSite.count, 3)
        XCTAssertEqual(speciesAtSite[0].name, "Common Species")
        XCTAssertEqual(speciesAtSite[1].name, "Occasional Species")
        XCTAssertEqual(speciesAtSite[2].name, "Rare Species")
    }

    func testFetchForSite_returnsEmptyForSiteWithNoLinks() throws {
        // Create species but no links
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "sp1", name: "Clownfish")
        ])

        // Create site with no links
        let siteRepo = SiteRepository(database: database)
        let site = TestDatabase.makeSite(id: "site1", name: "Empty Site")
        try siteRepo.create(site)

        let speciesAtSite = try speciesRepository.fetchForSite("site1")

        XCTAssertTrue(speciesAtSite.isEmpty)
    }

    // MARK: - Category Filter Tests

    func testFetchByCategory_filtersCorrectly() throws {
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "1", name: "Clownfish", category: .fish),
            TestDatabase.makeSpecies(id: "2", name: "Dolphin", category: .mammal),
            TestDatabase.makeSpecies(id: "3", name: "Sea Turtle", category: .reptile),
            TestDatabase.makeSpecies(id: "4", name: "Brain Coral", category: .coral)
        ])

        let fishSpecies = try speciesRepository.fetchByCategory(.fish)
        XCTAssertEqual(fishSpecies.count, 1)
        XCTAssertEqual(fishSpecies.first?.name, "Clownfish")

        let mammals = try speciesRepository.fetchByCategory(.mammal)
        XCTAssertEqual(mammals.count, 1)
        XCTAssertEqual(mammals.first?.name, "Dolphin")
    }

    // MARK: - Count Tests

    func testCount_returnsCorrectCount() throws {
        XCTAssertEqual(try speciesRepository.count(), 0)

        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "1", name: "Species 1"),
            TestDatabase.makeSpecies(id: "2", name: "Species 2"),
            TestDatabase.makeSpecies(id: "3", name: "Species 3")
        ])

        XCTAssertEqual(try speciesRepository.count(), 3)
    }

    func testCountSiteLinks_returnsCorrectCount() throws {
        // Create species and site
        try speciesRepository.createMany([
            TestDatabase.makeSpecies(id: "sp1", name: "Species 1"),
            TestDatabase.makeSpecies(id: "sp2", name: "Species 2")
        ])

        let siteRepo = SiteRepository(database: database)
        try siteRepo.create(TestDatabase.makeSite(id: "site1", name: "Test Site"))

        XCTAssertEqual(try speciesRepository.countSiteLinks(), 0)

        try speciesRepository.createSiteLinks([
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp1"),
            TestDatabase.makeSiteSpeciesLink(siteId: "site1", speciesId: "sp2")
        ])

        XCTAssertEqual(try speciesRepository.countSiteLinks(), 2)
    }
}
