import XCTest

/// Tests the Calendar module — empty state, sync, refresh, event sections.
final class CalendarTests: RyanHubUITestBase {

    func testCalendarCompleteFlow() throws {
        step("Navigate to Calendar plugin")
        navigateToPlugin("calendar")

        // STEP 1: Calendar should show some content
        step("Verify Calendar loads")
        let emptyState = find("calendar_empty_state")
        let todaySection = find("calendar_today_section")
        let syncButton = app.buttons["calendar_sync_button"]

        XCTAssertTrue(
            emptyState.exists || todaySection.exists || exists(syncButton, timeout: 3),
            "Calendar should show empty state, today section, or sync button"
        )

        // STEP 2: If empty state, test sync button
        if emptyState.exists {
            step("Empty state: verify sync button")
            waitFor(syncButton, message: "Sync button should exist in empty state")

            step("Empty state: tap sync button")
            syncButton.tap()
            usleep(1_500_000)

            // After sync attempt, check what happened
            // Might still be empty (no Google Calendar connected) or might show events
            let stillEmpty = find("calendar_empty_state")
            let nowHasToday = find("calendar_today_section")
            step("After sync: empty=\(stillEmpty.exists), hasToday=\(nowHasToday.exists)")
        }

        // STEP 3: Refresh button in toolbar
        step("Verify refresh button")
        let refreshBtn = app.buttons["calendar_refresh_button"]
        if exists(refreshBtn, timeout: 3) {
            step("Tap refresh button")
            refreshBtn.tap()
            usleep(1_000_000)
        }

        // STEP 4: Check for countdown section
        step("Check countdown section")
        let countdown = find("calendar_countdown")
        if countdown.exists {
            step("Countdown section is visible")
        }

        // STEP 5: Check for week overview
        step("Check week overview")
        let weekOverview = find("calendar_week_overview")
        if weekOverview.exists {
            step("Week overview is visible")
        }

        // STEP 6: Scroll through content
        step("Scroll through calendar content")
        scrollContentUp()

        // STEP 7: Check for tomorrow section
        let tomorrowSection = find("calendar_tomorrow_section")
        if tomorrowSection.exists {
            step("Tomorrow section is visible")
        }

        // STEP 8: Check week section
        let weekSection = find("calendar_week_section")
        if weekSection.exists {
            step("Week section is visible")
        }

        // Scroll back
        scrollContentDown()
    }
}
