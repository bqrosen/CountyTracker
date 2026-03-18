import XCTest

final class CountyTrackerUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launchArguments += ["-uiTesting"]
        setupSnapshot(app)
    }

    func testTakeScreenshots() throws {
        app.launch()
        // Wait briefly for the app to stabilize
        sleep(2)

        // Main launch screenshot
        snapshot("01Launch")

        // Helper to tap an element if it exists within timeout.
        func tapIfExists(_ element: XCUIElement, timeout: TimeInterval = 2) {
            if element.waitForExistence(timeout: timeout) {
                element.tap()
                sleep(1)
            }
        }

        // Attempt to navigate to a "Visited" view (common label/identifier examples).
        tapIfExists(app.buttons["Visited"])
        tapIfExists(app.buttons["VisitedButton"]) // alternate id
        tapIfExists(app.buttons["VisitedView"])   // alternate id
        snapshot("02Visited")

        // Attempt to open list/detail for a county and snapshot detail view.
        // This will try cells and common list buttons; adapt identifiers as needed.
        if app.tables.firstMatch.waitForExistence(timeout: 2) {
            let firstCell = app.tables.firstMatch.cells.firstMatch
            tapIfExists(firstCell)
            snapshot("03CountyDetail")

            // Try to go back
            if app.navigationBars.buttons.firstMatch.exists {
                tapIfExists(app.navigationBars.buttons.firstMatch)
            } else {
                tapIfExists(app.buttons["Back"])
            }
        }

        // Attempt to open Settings and snapshot
        tapIfExists(app.buttons["Settings"])
        tapIfExists(app.buttons["SettingsButton"]) // alternate id
        snapshot("04Settings")

        // Attempt an About/Info screen snapshot
        tapIfExists(app.buttons["About"])
        tapIfExists(app.buttons["AboutButton"]) // alternate id
        snapshot("05About")

        // Note: these are best-effort taps — update the accessibility identifiers
        // in your app (or these strings) to make navigation deterministic.
    }
}
