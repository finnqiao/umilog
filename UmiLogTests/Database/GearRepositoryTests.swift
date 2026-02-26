import XCTest
@testable import UmiDB

final class GearRepositoryTests: XCTestCase {
    private var database: AppDatabase!
    private var repository: GearRepository!

    override func setUpWithError() throws {
        database = try TestDatabase.makeInMemory()
        repository = GearRepository(database: database)
    }

    override func tearDownWithError() throws {
        database = nil
        repository = nil
    }

    func testUpsertAndFetchAll() throws {
        let item = TestDatabase.makeGearItem(id: "gear-1", name: "Primary Reg")

        try repository.upsert(item)
        let all = try repository.fetchAll()

        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, "gear-1")
        XCTAssertEqual(all.first?.name, "Primary Reg")
    }

    func testFetchActiveFiltersRetiredItems() throws {
        try repository.upsert(TestDatabase.makeGearItem(id: "active", isActive: true))
        try repository.upsert(TestDatabase.makeGearItem(id: "retired", isActive: false))

        let active = try repository.fetchActive()

        XCTAssertEqual(active.count, 1)
        XCTAssertEqual(active.first?.id, "active")
    }

    func testFetchServiceDueReturnsDueGear() throws {
        let dueDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let futureDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

        try repository.upsert(TestDatabase.makeGearItem(id: "due", nextServiceDate: dueDate))
        try repository.upsert(TestDatabase.makeGearItem(id: "future", nextServiceDate: futureDate))

        let due = try repository.fetchServiceDue(referenceDate: Date())

        XCTAssertEqual(due.map(\.id), ["due"])
    }
}
