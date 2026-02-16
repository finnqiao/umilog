import XCTest
@testable import FeatureLiveLog
@testable import UmiDB

@MainActor
final class DiveLoggerViewModelTests: XCTestCase {
    var viewModel: DiveLoggerViewModel!

    override func setUp() async throws {
        viewModel = DiveLoggerViewModel()
        // Give the viewModel a test site
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Validation Tests

    func testCanSave_requiresSite() async {
        viewModel.selectedSite = nil
        viewModel.maxDepth = "25"
        viewModel.bottomTime = "45"

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_requiresMaxDepth() async {
        viewModel.maxDepth = ""
        viewModel.bottomTime = "45"

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_requiresBottomTime() async {
        viewModel.maxDepth = "25"
        viewModel.bottomTime = ""

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_requiresValidNumbers() async {
        viewModel.maxDepth = "not a number"
        viewModel.bottomTime = "45"

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_returnsTrueWhenValid() async {
        viewModel.maxDepth = "25"
        viewModel.bottomTime = "45"

        XCTAssertTrue(viewModel.canSave)
    }

    // MARK: - Filtered Sites Tests

    func testFilteredSites_returnsAllWhenQueryEmpty() async {
        viewModel.availableSites = [
            TestDatabase.makeSite(id: "1", name: "Blue Hole"),
            TestDatabase.makeSite(id: "2", name: "Shark Reef"),
            TestDatabase.makeSite(id: "3", name: "Coral Garden")
        ]
        viewModel.siteSearchQuery = ""

        XCTAssertEqual(viewModel.filteredSites.count, 3)
    }

    func testFilteredSites_filtersByName() async {
        viewModel.availableSites = [
            TestDatabase.makeSite(id: "1", name: "Blue Hole"),
            TestDatabase.makeSite(id: "2", name: "Shark Reef"),
            TestDatabase.makeSite(id: "3", name: "Blue Lagoon")
        ]
        viewModel.siteSearchQuery = "Blue"

        XCTAssertEqual(viewModel.filteredSites.count, 2)
    }

    func testFilteredSites_caseInsensitive() async {
        viewModel.availableSites = [
            TestDatabase.makeSite(id: "1", name: "Blue Hole"),
            TestDatabase.makeSite(id: "2", name: "Shark Reef")
        ]
        viewModel.siteSearchQuery = "blue"

        XCTAssertEqual(viewModel.filteredSites.count, 1)
        XCTAssertEqual(viewModel.filteredSites.first?.name, "Blue Hole")
    }

    // MARK: - Default Values Tests

    func testDefaultValues_areReasonable() async {
        XCTAssertEqual(viewModel.startPressure, "200")
        XCTAssertEqual(viewModel.endPressure, "50")
        XCTAssertEqual(viewModel.temperature, "27")
        XCTAssertEqual(viewModel.visibility, "30")
        XCTAssertEqual(viewModel.current, .none)
        XCTAssertEqual(viewModel.conditions, .good)
    }

    // MARK: - State Tests

    func testInitialState_isNotSaved() async {
        XCTAssertFalse(viewModel.isSaved)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertNil(viewModel.error)
    }
}
