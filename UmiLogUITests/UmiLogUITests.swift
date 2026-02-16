import XCTest

final class UmiLogUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunchPerformance() throws {
        // Placeholder UI test - measures app launch time
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    func testOnboardingCompletionAndRelaunchStability() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-DisableAnimations", "--skip-location-prompt"]
        app.launch()

        if app.staticTexts["Welcome to UmiLog"].waitForExistence(timeout: 8) {
            tapIfExists("Get Started", in: app, timeout: 3)

            for _ in 0..<12 {
                if tapIfExists("Start Exploring", in: app, timeout: 1) { break }
                if tapIfExists("Continue", in: app, timeout: 1) { continue }
                if tapIfExists("Skip", in: app, timeout: 1) { continue }
                if tapIfExists("Skip for Now", in: app, timeout: 1) { continue }
                if tapIfExists("Enable Location", in: app, timeout: 1) { continue }
            }
        }

        XCTAssertTrue(
            app.buttons["Map"].waitForExistence(timeout: 15),
            "Expected app to reach main tab UI after onboarding"
        )

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.buttons["Map"].waitForExistence(timeout: 15),
            "Expected app to relaunch after onboarding completion"
        )
    }

    @MainActor
    func testForcedSafeModeLaunchAndRelaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITest", "-SkipOnboarding", "-DisableAnimations", "-ForceLaunchSafeMode"]
        app.launch()

        XCTAssertTrue(
            app.buttons["Map"].waitForExistence(timeout: 15),
            "Expected app to launch to map tab while safe mode is forced"
        )

        app.terminate()
        app.launch()

        XCTAssertTrue(
            app.buttons["Map"].waitForExistence(timeout: 15),
            "Expected app to relaunch to map tab while safe mode is forced"
        )
    }

    @MainActor
    @discardableResult
    private func tapIfExists(_ label: String, in app: XCUIApplication, timeout: TimeInterval) -> Bool {
        let button = app.buttons[label]
        guard button.waitForExistence(timeout: timeout) else { return false }
        button.tap()
        return true
    }
}
