import XCTest

/// Tests the Parking module — today status, calendar navigation, month switching.
final class ParkingTests: RyanHubUITestBase {

    func testParkingCompleteFlow() throws {
        step("Navigate to Parking plugin")
        navigateToPlugin("parking")

        // STEP 1: Today's status card
        step("Verify today's status card")
        let todayStatus = find("parking_today_status")
        XCTAssertTrue(todayStatus.exists, "Today's status card should exist")

        // STEP 2: Scroll down to calendar section
        step("Scroll to calendar section")
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        usleep(500_000)

        // STEP 3: Calendar section visible
        step("Verify calendar section")
        let calendar = find("parking_calendar")
        XCTAssertTrue(calendar.exists, "Calendar section should exist")

        // STEP 4: Month navigation buttons
        step("Verify month navigation buttons")
        let prevMonth = app.buttons["parking_prev_month"]
        let nextMonth = app.buttons["parking_next_month"]
        waitFor(prevMonth, message: "Previous month button should exist")
        waitFor(nextMonth, message: "Next month button should exist")

        // STEP 5: Month label
        step("Verify month label")
        let monthLabel = app.staticTexts["parking_month_label"]
        waitFor(monthLabel, message: "Month label should exist")
        let initialMonth = monthLabel.label

        // STEP 6: Navigate to next month
        step("Navigate to next month")
        nextMonth.tap()
        usleep(500_000)
        let afterNext = monthLabel.label
        XCTAssertNotEqual(initialMonth, afterNext, "Month should change after tapping next. Was: '\(initialMonth)', now: '\(afterNext)'")

        // STEP 7: Navigate forward one more month
        step("Navigate to second next month")
        nextMonth.tap()
        usleep(500_000)
        let afterSecondNext = monthLabel.label
        XCTAssertNotEqual(afterNext, afterSecondNext, "Month should change again after second next tap")

        // STEP 8: Navigate back twice to return
        step("Navigate back to original month")
        prevMonth.tap()
        usleep(300_000)
        prevMonth.tap()
        usleep(500_000)
        let afterBack = monthLabel.label
        XCTAssertEqual(initialMonth, afterBack, "Month should return to original '\(initialMonth)' after going back twice, got: '\(afterBack)'")

        // STEP 9: Try to tap a date cell in the calendar
        step("Tap a date cell in the calendar")
        // Date cells are buttons within the calendar — try to find any tappable date
        let dateCells = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'parking_date_'"))
        if dateCells.count > 0 {
            let firstDate = dateCells.element(boundBy: 0)
            firstDate.tap()
            usleep(500_000)

            // Check if a confirmation or toggle appeared
            let confirmation = find("parking_confirmation")
            if confirmation.exists {
                step("Date toggle confirmation visible")
            }
        }

        // STEP 10: Scroll back up to verify today status still shows
        step("Scroll back to top")
        scrollView.swipeDown()
        usleep(300_000)
        XCTAssertTrue(todayStatus.exists, "Today's status should still be visible after scrolling back")
    }
}
