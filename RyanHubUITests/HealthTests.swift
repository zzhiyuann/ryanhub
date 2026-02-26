import XCTest

final class HealthTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToPlugin("health")
    }

    func testHealthViewLoads() throws {
        let weightTab = app.buttons["health_tab_weight"]
        XCTAssertTrue(waitForElement(weightTab), "Health weight tab should exist")
    }

    func testAllTabsExist() throws {
        XCTAssertTrue(app.buttons["health_tab_weight"].exists, "Weight tab should exist")
        XCTAssertTrue(app.buttons["health_tab_food"].exists, "Food tab should exist")
        XCTAssertTrue(app.buttons["health_tab_activity"].exists, "Activity tab should exist")
    }

    func testWeightTabContent() throws {
        // Weight tab should be selected by default
        let logButton = app.buttons["health_log_weight_button"]
        XCTAssertTrue(waitForElement(logButton), "Log Weight button should exist")
    }

    func testSwitchToFoodTab() throws {
        app.buttons["health_tab_food"].tap()

        let mealInput = app.textFields["health_quick_meal_input"]
        XCTAssertTrue(waitForElement(mealInput), "Quick meal input should appear on food tab")
    }

    func testSwitchToActivityTab() throws {
        app.buttons["health_tab_activity"].tap()

        let activityInput = app.textFields["health_quick_activity_input"]
        let todayActivity = app.otherElements["health_today_activity"]
        XCTAssertTrue(
            waitForElement(activityInput) || waitForElement(todayActivity),
            "Activity content should appear"
        )
    }

    func testLogWeightOpensSheet() throws {
        let logButton = app.buttons["health_log_weight_button"]
        XCTAssertTrue(waitForElement(logButton))
        logButton.tap()

        // Sheet should appear with a "Save" button
        let saveButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save'")).firstMatch
        XCTAssertTrue(waitForElement(saveButton, timeout: 3), "Weight log sheet should appear with save button")
    }

    func testFoodTabPhotoButton() throws {
        app.buttons["health_tab_food"].tap()

        let photo = app.buttons["health_photo_button"]
        XCTAssertTrue(waitForElement(photo), "Photo button should exist on food tab")
    }

    func testActivityQuickInput() throws {
        app.buttons["health_tab_activity"].tap()

        let input = app.textFields["health_quick_activity_input"]
        XCTAssertTrue(waitForElement(input))
        input.tap()
        input.typeText("Walked 30 min")

        let submit = app.buttons["health_quick_activity_submit"]
        XCTAssertTrue(waitForElement(submit, timeout: 3), "Activity submit button should appear")
    }

    func testStructuredLogButton() throws {
        app.buttons["health_tab_activity"].tap()

        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let structuredLog = app.buttons["health_structured_log_button"]
        XCTAssertTrue(waitForElement(structuredLog), "Structured Log button should exist")
    }
}
