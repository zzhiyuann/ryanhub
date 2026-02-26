import XCTest

final class CalendarTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToPlugin("calendar")
    }

    func testCalendarViewLoads() throws {
        // Calendar should show empty state or content
        let emptyState = app.otherElements["calendar_empty_state"]
        let todaySection = app.otherElements["calendar_today_section"]
        let syncButton = app.buttons["calendar_sync_button"]
        XCTAssertTrue(
            waitForElement(emptyState) || waitForElement(todaySection) || waitForElement(syncButton),
            "Calendar should show some content"
        )
    }

    func testEmptyStateHasSyncButton() throws {
        let emptyState = app.otherElements["calendar_empty_state"]
        if waitForElement(emptyState, timeout: 3) {
            let syncButton = app.buttons["calendar_sync_button"]
            XCTAssertTrue(waitForElement(syncButton), "Sync button should exist in empty state")
        }
        // If not empty state, that's fine too
    }

    func testRefreshButtonInToolbar() throws {
        let refresh = app.buttons["calendar_refresh_button"]
        XCTAssertTrue(waitForElement(refresh), "Refresh button should exist in toolbar")
    }
}
