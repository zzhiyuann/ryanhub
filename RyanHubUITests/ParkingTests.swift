import XCTest

final class ParkingTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToPlugin("parking")
    }

    func testParkingViewLoads() throws {
        let todayStatus = app.otherElements["parking_today_status"]
        XCTAssertTrue(waitForElement(todayStatus), "Today status card should exist")
    }

    func testCalendarSectionExists() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let calendar = app.otherElements["parking_calendar"]
        XCTAssertTrue(waitForElement(calendar), "Calendar section should exist")
    }

    func testMonthNavigationButtons() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let prevMonth = app.buttons["parking_prev_month"]
        let nextMonth = app.buttons["parking_next_month"]
        let monthLabel = app.staticTexts["parking_month_label"]

        XCTAssertTrue(waitForElement(prevMonth), "Previous month button should exist")
        XCTAssertTrue(waitForElement(nextMonth), "Next month button should exist")
        XCTAssertTrue(waitForElement(monthLabel), "Month label should exist")
    }

    func testMonthNavigation() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let monthLabel = app.staticTexts["parking_month_label"]
        XCTAssertTrue(waitForElement(monthLabel))
        let initialMonth = monthLabel.label

        let nextMonth = app.buttons["parking_next_month"]
        nextMonth.tap()

        // Month label should change
        sleep(1)
        let newMonth = monthLabel.label
        XCTAssertNotEqual(initialMonth, newMonth, "Month should change after tapping next")

        // Go back
        let prevMonth = app.buttons["parking_prev_month"]
        prevMonth.tap()

        sleep(1)
        let backMonth = monthLabel.label
        XCTAssertEqual(initialMonth, backMonth, "Month should return to original after going back")
    }
}
