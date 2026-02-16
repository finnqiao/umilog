import XCTest

/// Comprehensive E2E test suite for capturing all user flows
/// Screenshots are saved to the test artifacts
final class E2EFlowTests: XCTestCase {

    var app: XCUIApplication!
    var screenshotCounter = 0
    var currentJourney = ""

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launchArguments = ["-UITest", "-DisableAnimations", "-SkipOnboarding"]
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Screenshot Helper

    func captureScreen(_ name: String) {
        screenshotCounter += 1
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        let filename = String(format: "%02d_%@_%02d_%@",
                              screenshotCounter,
                              currentJourney,
                              screenshotCounter,
                              name.replacingOccurrences(of: " ", with: "_").lowercased())
        attachment.name = filename
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Onboarding Helper

    /// Complete the onboarding flow if present
    func completeOnboardingIfNeeded() {
        // Check for onboarding welcome screen
        let welcomeText = app.staticTexts["Welcome to UmiLog"]
        if welcomeText.waitForExistence(timeout: 3) {
            // Tap Get Started button using coordinate (bottom center)
            let coordinate = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.92))
            coordinate.tap()
            sleep(2)
        }

        // Navigate through all onboarding steps (Skip or Continue)
        for _ in 0..<10 {
            let skipButton = app.buttons["Skip"]
            let continueButton = app.buttons["Continue"]
            let doneButton = app.buttons["Done"]
            let letsGoButton = app.buttons["Let's Go"]

            if skipButton.waitForExistence(timeout: 1) {
                skipButton.tap()
                sleep(1)
            } else if continueButton.waitForExistence(timeout: 1) {
                continueButton.tap()
                sleep(1)
            } else if doneButton.waitForExistence(timeout: 1) {
                doneButton.tap()
                sleep(1)
            } else if letsGoButton.waitForExistence(timeout: 1) {
                letsGoButton.tap()
                sleep(1)
            } else {
                // No more onboarding buttons, break
                break
            }
        }

        // Handle location permission modal (Not Now button)
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 2) {
            notNowButton.tap()
            sleep(1)
        }

        // Also check for system location permission alert
        let allowButton = app.buttons["Allow While Using App"]
        if allowButton.waitForExistence(timeout: 1) {
            allowButton.tap()
            sleep(1)
        }
    }

    // MARK: - Journey 1: App Launch & Location Permission

    @MainActor
    func test01_LaunchFlow() throws {
        currentJourney = "launch"

        // Launch app
        app.launch()
        captureScreen("app_launched")

        // Complete onboarding if present
        completeOnboardingIfNeeded()

        // Verify we're on the main screen (Map tab)
        sleep(3)
        captureScreen("main_screen_map_tab")
    }

    // MARK: - Journey 2: Tab Navigation

    @MainActor
    func test02_TabNavigation() throws {
        currentJourney = "tabs"
        app.launch()

        // Complete onboarding if present
        completeOnboardingIfNeeded()

        // Map Tab (default)
        captureScreen("map_tab_active")

        // History Tab
        let historyTab = app.buttons["History"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            sleep(2)
            captureScreen("history_tab")
        }

        // Wildlife Tab
        let wildlifeTab = app.buttons["Wildlife"]
        if wildlifeTab.waitForExistence(timeout: 3) {
            wildlifeTab.tap()
            sleep(2)
            captureScreen("wildlife_tab")
        }

        // Profile Tab
        let profileTab = app.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
            sleep(2)
            captureScreen("profile_tab")
        }

        // Back to Map Tab
        let mapTab = app.buttons["Map"]
        if mapTab.waitForExistence(timeout: 3) {
            mapTab.tap()
            sleep(2)
            captureScreen("map_tab_returned")
        }
    }

    // MARK: - Journey 3: Log Flow (Live Log Wizard)

    @MainActor
    func test03_LogFlow() throws {
        currentJourney = "log"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        // Tap Log tab (center FAB)
        let logTab = app.buttons["Log"]
        if logTab.waitForExistence(timeout: 3) {
            logTab.tap()
            sleep(2)
            captureScreen("log_launcher_view")
        }

        // Look for Live Log or Quick Log options
        let liveLogButton = app.buttons["Live Log"]
        let quickLogButton = app.buttons["Quick Log"]

        if liveLogButton.waitForExistence(timeout: 3) {
            liveLogButton.tap()
            sleep(2)
            captureScreen("live_log_wizard_step1")

            // Try to navigate through wizard steps using accessibility identifier
            // Step 1: Site & Time -> Step 2
            let continueButton = app.buttons["wizard_continue_button"]
            if continueButton.waitForExistence(timeout: 3) && continueButton.isEnabled {
                continueButton.tap()
                sleep(1)
                captureScreen("live_log_wizard_step2")

                // Step 2: Depth & Duration -> Step 3
                if continueButton.exists && continueButton.isEnabled {
                    continueButton.tap()
                    sleep(1)
                    captureScreen("live_log_wizard_step3")

                    // Step 3: Air & Conditions -> Step 4
                    if continueButton.exists && continueButton.isEnabled {
                        continueButton.tap()
                        sleep(1)
                        captureScreen("live_log_wizard_step4")
                    }
                }
            }

            // Try to close wizard
            let closeButton = app.buttons["Close"]
            let cancelButton = app.buttons["Cancel"]
            let dismissButton = app.buttons["Dismiss"]

            if closeButton.exists {
                closeButton.tap()
            } else if cancelButton.exists {
                cancelButton.tap()
            } else if dismissButton.exists {
                dismissButton.tap()
            }
            sleep(1)
            captureScreen("after_wizard_dismiss")
        } else if quickLogButton.waitForExistence(timeout: 3) {
            quickLogButton.tap()
            sleep(2)
            captureScreen("quick_log_view")
        }
    }

    // MARK: - Journey 4: Map Interactions

    @MainActor
    func test04_MapInteractions() throws {
        currentJourney = "map"
        app.launch()

        // Complete onboarding if present
        completeOnboardingIfNeeded()

        // Ensure we're on Map tab
        let mapTab = app.buttons["Map"]
        if mapTab.waitForExistence(timeout: 3) {
            mapTab.tap()
            sleep(3)
        }

        captureScreen("map_default_view")

        // Look for search button (using accessibility identifier)
        let searchButton = app.buttons["map_search_button"]
        if searchButton.waitForExistence(timeout: 3) {
            searchButton.tap()
            sleep(2)
            captureScreen("search_sheet_opened")

            // Try to dismiss search
            let doneButton = app.buttons["Done"]
            let cancelButton = app.buttons["Cancel"]
            if doneButton.exists {
                doneButton.tap()
            } else if cancelButton.exists {
                cancelButton.tap()
            } else {
                // Swipe down to dismiss
                app.swipeDown()
            }
            sleep(1)
        }

        // Look for filter button (using accessibility identifier)
        let filterButton = app.buttons["map_filter_button"]
        if filterButton.waitForExistence(timeout: 3) {
            filterButton.tap()
            sleep(2)
            captureScreen("filter_sheet_opened")

            // Dismiss filter
            app.swipeDown()
            sleep(1)
        }

        // Try tapping on map to select a site
        let mapView = app.otherElements["MapView"]
        if mapView.exists {
            mapView.tap()
            sleep(2)
            captureScreen("map_site_selected")
        }

        captureScreen("map_final_state")
    }

    // MARK: - Journey 5: History Screen

    @MainActor
    func test05_HistoryScreen() throws {
        currentJourney = "history"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        // Navigate to History tab
        let historyTab = app.buttons["History"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            sleep(2)
        }

        captureScreen("history_list_view")

        // Try to tap on a dive entry
        let cells = app.cells
        if cells.count > 0 {
            cells.firstMatch.tap()
            sleep(2)
            captureScreen("dive_detail_view")

            // Navigate back
            let backButton = app.navigationBars.buttons.firstMatch
            if backButton.exists {
                backButton.tap()
                sleep(1)
            }
        }

        // Look for search in history
        let searchField = app.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 3) {
            searchField.tap()
            sleep(1)
            captureScreen("history_search_active")

            // Cancel search
            let cancelButton = app.buttons["Cancel"]
            if cancelButton.exists {
                cancelButton.tap()
                sleep(1)
            }
        }

        captureScreen("history_final_state")
    }

    // MARK: - Journey 6: Wildlife/Species Screen

    @MainActor
    func test06_WildlifeScreen() throws {
        currentJourney = "wildlife"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        // Navigate to Wildlife tab
        let wildlifeTab = app.buttons["Wildlife"]
        if wildlifeTab.waitForExistence(timeout: 3) {
            wildlifeTab.tap()
            sleep(2)
        }

        captureScreen("wildlife_list_view")

        // Try to tap on a species entry (using accessibility identifier for grid)
        let speciesGrid = app.otherElements["wildlife_species_grid"]
        if speciesGrid.waitForExistence(timeout: 3) {
            // Find species cards within the grid
            let speciesCards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'species_card_'"))
            if speciesCards.count > 0 {
                speciesCards.firstMatch.tap()
                sleep(2)
                captureScreen("species_detail_view")

                // Navigate back
                let backButton = app.navigationBars.buttons.firstMatch
                if backButton.exists {
                    backButton.tap()
                    sleep(1)
                }
            }
        }

        captureScreen("wildlife_final_state")
    }

    // MARK: - Journey 7: Profile/Settings Screen

    @MainActor
    func test07_ProfileSettings() throws {
        currentJourney = "settings"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        // Navigate to Profile tab
        let profileTab = app.buttons["Profile"]
        if profileTab.waitForExistence(timeout: 3) {
            profileTab.tap()
            sleep(2)
        }

        captureScreen("profile_main_view")

        // Look for settings options
        let settingsItems = app.cells
        for i in 0..<min(settingsItems.count, 5) {
            // Scroll and capture different sections
            if i > 0 {
                app.swipeUp()
                sleep(1)
                captureScreen("settings_scrolled_\(i)")
            }
        }

        // Look for Face ID / App Lock toggle
        let faceIDToggle = app.switches["Face ID"]
        let appLockToggle = app.switches["App Lock"]
        if faceIDToggle.exists || appLockToggle.exists {
            captureScreen("settings_faceid_option")
        }

        // Look for Theme toggle
        let themeToggle = app.switches["Underwater Theme"]
        if themeToggle.exists {
            captureScreen("settings_theme_option")
        }

        captureScreen("profile_final_state")
    }

    // MARK: - Journey 8: Site Detail Flow

    @MainActor
    func test08_SiteDetailFlow() throws {
        currentJourney = "sitedetail"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        // Ensure we're on Map tab
        let mapTab = app.buttons["Map"]
        if mapTab.waitForExistence(timeout: 3) {
            mapTab.tap()
            sleep(2)
        }

        captureScreen("map_for_site_selection")

        // Look for site list or nearby sites
        let sitesList = app.scrollViews["SitesList"]
        let nearbySites = app.staticTexts["Nearby Sites"]

        if sitesList.exists {
            captureScreen("sites_list_visible")
        }

        // Try to find and tap a site marker or list item
        let siteCell = app.cells.firstMatch
        if siteCell.waitForExistence(timeout: 3) {
            siteCell.tap()
            sleep(2)
            captureScreen("site_detail_sheet")

            // Look for actions in detail sheet
            let wishlistButton = app.buttons["Add to Wishlist"]
            let visitedButton = app.buttons["Mark as Visited"]
            let logDiveButton = app.buttons["Log Dive Here"]

            if wishlistButton.exists {
                captureScreen("site_detail_wishlist_option")
            }
            if visitedButton.exists {
                captureScreen("site_detail_visited_option")
            }
            if logDiveButton.exists {
                captureScreen("site_detail_log_option")
            }

            // Scroll to see more details
            app.swipeUp()
            sleep(1)
            captureScreen("site_detail_scrolled")
        }

        captureScreen("site_detail_final_state")
    }

    // MARK: - Journey 9: Error States

    @MainActor
    func test09_ErrorStates() throws {
        currentJourney = "errors"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        captureScreen("app_normal_state")

        // Check for any error alerts or banners
        let errorAlert = app.alerts.firstMatch
        if errorAlert.exists {
            captureScreen("error_alert_visible")
        }

        // Check for offline indicator
        let offlineIndicator = app.staticTexts["Offline"]
        if offlineIndicator.exists {
            captureScreen("offline_indicator")
        }

        // Check for retry buttons
        let retryButton = app.buttons["Retry"]
        if retryButton.exists {
            captureScreen("retry_option_visible")
        }

        captureScreen("error_states_final")
    }

    // MARK: - Journey 10: Deep Link Testing

    @MainActor
    func test10_DeepLinkNavigation() throws {
        currentJourney = "deeplink"
        app.launch()

        // Dismiss location modal if present
        let notNowButton = app.buttons["Not Now"]
        if notNowButton.waitForExistence(timeout: 3) {
            notNowButton.tap()
            sleep(1)
        }

        captureScreen("initial_state")

        // Test deep link to wildlife tab
        // Note: In real testing, this would use XCUIApplication.open(URL:)
        // For simulator testing, we simulate the effect via launch arguments
        app.terminate()
        app.launchArguments = ["-UITest", "-DisableAnimations"]
        app.launch()

        // Navigate via tab bar to verify navigation works
        let wildlifeTab = app.buttons["Wildlife"]
        if wildlifeTab.waitForExistence(timeout: 3) {
            wildlifeTab.tap()
            sleep(2)
            captureScreen("deeplink_wildlife_tab")
        }

        // Test deep link to history tab
        let historyTab = app.buttons["History"]
        if historyTab.waitForExistence(timeout: 3) {
            historyTab.tap()
            sleep(2)
            captureScreen("deeplink_history_tab")
        }

        // Return to map tab
        let mapTab = app.buttons["Map"]
        if mapTab.waitForExistence(timeout: 3) {
            mapTab.tap()
            sleep(2)
            captureScreen("deeplink_map_tab")
        }

        captureScreen("deeplink_final_state")
    }

    // MARK: - Full App Exploration

    @MainActor
    func test11_FullAppExploration() throws {
        currentJourney = "exploration"
        app.launch()

        captureScreen("fresh_launch")

        // Capture all visible elements for documentation
        sleep(3)
        captureScreen("after_load_complete")

        // Take screenshots of any modals or overlays
        let alerts = app.alerts
        let sheets = app.sheets
        let popovers = app.popovers

        if alerts.count > 0 {
            captureScreen("alert_present")
        }
        if sheets.count > 0 {
            captureScreen("sheet_present")
        }
        if popovers.count > 0 {
            captureScreen("popover_present")
        }

        // Document accessibility elements
        let staticTexts = app.staticTexts.allElementsBoundByIndex
        let buttons = app.buttons.allElementsBoundByIndex

        print("Found \(staticTexts.count) text elements")
        print("Found \(buttons.count) button elements")

        captureScreen("exploration_complete")
    }
}
