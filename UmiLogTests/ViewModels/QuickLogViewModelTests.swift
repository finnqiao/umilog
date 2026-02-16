import XCTest
@testable import FeatureLiveLog
@testable import UmiDB

@MainActor
final class QuickLogViewModelTests: XCTestCase {
    var viewModel: QuickLogViewModel!

    override func setUp() async throws {
        viewModel = QuickLogViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
    }

    // MARK: - Validation Tests

    func testCanSave_requiresSiteOrGPS() async {
        viewModel.selectedSite = nil
        viewModel.gpsLatitude = nil
        viewModel.gpsLongitude = nil
        viewModel.maxDepth = 25
        viewModel.bottomTime = 45

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_worksWithSite() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 25
        viewModel.bottomTime = 45

        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSave_worksWithGPS() async {
        viewModel.selectedSite = nil
        viewModel.gpsLatitude = 27.5
        viewModel.gpsLongitude = 33.8
        viewModel.maxDepth = 25
        viewModel.bottomTime = 45

        XCTAssertTrue(viewModel.canSave)
    }

    func testCanSave_requiresDepth() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 0
        viewModel.bottomTime = 45

        XCTAssertFalse(viewModel.canSave)
    }

    func testCanSave_requiresBottomTime() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 25
        viewModel.bottomTime = 0

        XCTAssertFalse(viewModel.canSave)
    }

    // MARK: - Validation Feedback Tests

    func testValidateAndShowFeedback_noSite_showsError() async {
        viewModel.selectedSite = nil
        viewModel.gpsLatitude = nil
        viewModel.maxDepth = 25
        viewModel.bottomTime = 45

        let result = viewModel.validateAndShowFeedback()

        XCTAssertFalse(result)
        XCTAssertTrue(viewModel.showValidation)
        XCTAssertNotNil(viewModel.validationMessage)
        XCTAssertTrue(viewModel.shakeButton)
    }

    func testValidateAndShowFeedback_noDepth_showsError() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 0
        viewModel.bottomTime = 45

        let result = viewModel.validateAndShowFeedback()

        XCTAssertFalse(result)
        XCTAssertTrue(viewModel.showValidation)
        XCTAssertTrue(viewModel.validationMessage?.contains("depth") == true)
    }

    func testValidateAndShowFeedback_noBottomTime_showsError() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 25
        viewModel.bottomTime = 0

        let result = viewModel.validateAndShowFeedback()

        XCTAssertFalse(result)
        XCTAssertTrue(viewModel.showValidation)
        XCTAssertTrue(viewModel.validationMessage?.contains("time") == true)
    }

    func testValidateAndShowFeedback_validData_returnsTrue() async {
        viewModel.selectedSite = TestDatabase.makeSite(name: "Test Site")
        viewModel.maxDepth = 25
        viewModel.bottomTime = 45

        let result = viewModel.validateAndShowFeedback()

        XCTAssertTrue(result)
        XCTAssertFalse(viewModel.showValidation)
    }

    // MARK: - Default Values Tests

    func testInitialState_hasReasonableDefaults() async {
        XCTAssertEqual(viewModel.maxDepth, 18.0)
        XCTAssertEqual(viewModel.bottomTime, 40)
        XCTAssertNil(viewModel.selectedSite)
        XCTAssertFalse(viewModel.isSaving)
        XCTAssertFalse(viewModel.showingError)
    }

    // MARK: - GPS Mode Tests

    func testIsUsingGPS_initiallyFalse() async {
        XCTAssertFalse(viewModel.isUsingGPS)
    }

    func testClearGPS_clearsAllGPSData() async {
        viewModel.gpsLatitude = 27.5
        viewModel.gpsLongitude = 33.8
        viewModel.gpsLocationName = "Test Location"
        viewModel.isUsingGPS = true

        viewModel.clearGPS()

        XCTAssertNil(viewModel.gpsLatitude)
        XCTAssertNil(viewModel.gpsLongitude)
        XCTAssertNil(viewModel.gpsLocationName)
        XCTAssertFalse(viewModel.isUsingGPS)
    }

    // MARK: - Save Button Title Tests

    func testSaveButtonTitle_recentDive() async {
        viewModel.diveDate = Date()

        XCTAssertEqual(viewModel.saveButtonTitle, "Log Dive")
    }

    func testSaveButtonTitle_pastDive() async {
        viewModel.diveDate = Date().addingTimeInterval(-7200) // 2 hours ago

        XCTAssertEqual(viewModel.saveButtonTitle, "Log Past Dive")
    }

    // MARK: - Last Dive Feature Tests

    func testHasLastDive_initiallyFalse() async {
        XCTAssertFalse(viewModel.hasLastDive)
    }
}
