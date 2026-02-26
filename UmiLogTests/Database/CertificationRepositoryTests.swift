import XCTest
@testable import UmiDB

final class CertificationRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var repository: CertificationsRepository!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        repository = CertificationsRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
    }

    func testUpsertAndFetch() throws {
        let certification = TestDatabase.makeCertification(isPrimary: true)
        try repository.upsert(certification)

        let all = try repository.fetchAll()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, certification.id)
        XCTAssertEqual(all.first?.isPrimary, true)
    }

    func testPrimaryCertificationIsUnique() throws {
        let certOne = TestDatabase.makeCertification(id: "cert-1", level: "Open Water", isPrimary: true)
        let certTwo = TestDatabase.makeCertification(id: "cert-2", level: "Advanced Open Water", isPrimary: true)

        try repository.upsert(certOne)
        try repository.upsert(certTwo)

        let all = try repository.fetchAll()
        let primary = all.filter(\.isPrimary)
        XCTAssertEqual(primary.count, 1)
        XCTAssertEqual(primary.first?.id, certTwo.id)
    }

    func testDeletingPrimaryPromotesAnotherCertification() throws {
        let primary = TestDatabase.makeCertification(id: "primary", level: "Advanced", isPrimary: true)
        let secondary = TestDatabase.makeCertification(id: "secondary", level: "Rescue", isPrimary: false)

        try repository.upsert(primary)
        try repository.upsert(secondary)

        _ = try repository.delete(id: primary.id)
        let remaining = try repository.fetchAll()

        XCTAssertEqual(remaining.count, 1)
        XCTAssertEqual(remaining.first?.id, secondary.id)
        XCTAssertEqual(remaining.first?.isPrimary, true)
    }
}
