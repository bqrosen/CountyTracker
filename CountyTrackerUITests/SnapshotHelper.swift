import Foundation
import XCTest

var snapshotCounter = 0

func setupSnapshot(_ app: XCUIApplication) {
    setenv("FASTLANE_SNAPSHOT", "YES", 1)
}

func snapshot(_ name: String, waitForLoadingIndicator: Bool = true) {
    let fullName = name
    let screenshot = XCUIScreen.main.screenshot()
    let attachment = XCTAttachment(screenshot: screenshot)
    attachment.name = fullName
    attachment.lifetime = .keepAlways
    XCTContext.runActivity(named: "Snapshot: \(fullName)") { activity in
        activity.add(attachment)
    }
    snapshotCounter += 1
}
