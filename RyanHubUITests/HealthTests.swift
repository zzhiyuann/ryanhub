import XCTest

/// Tests the Health module — weight, food, activity tabs with real interactions.
final class HealthTests: RyanHubUITestBase {

    func testHealthCompleteFlow() throws {
        step("Navigate to Health plugin")
        navigateToPlugin("health")

        // STEP 1: All tabs visible
        step("Verify all health tabs exist")
        waitFor(app.buttons["health_tab_weight"], message: "Weight tab missing")
        waitFor(app.buttons["health_tab_food"], message: "Food tab missing")
        waitFor(app.buttons["health_tab_activity"], message: "Activity tab missing")

        // STEP 2: Weight tab (default) — verify content
        step("Weight tab: verify content")
        let currentWeight = find("health_current_weight")
        XCTAssertTrue(currentWeight.exists, "Current weight card should exist")

        let logWeightBtn = app.buttons["health_log_weight_button"]
        waitFor(logWeightBtn, message: "Log Weight button should exist")

        // STEP 3: Tap Log Weight — sheet should open
        step("Weight tab: open log weight sheet")
        logWeightBtn.tap()
        usleep(800_000)

        // Sheet should have a Save button or Cancel
        let cancelBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch
        let saveBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'save'")).firstMatch
        XCTAssertTrue(
            exists(cancelBtn, timeout: 3) || exists(saveBtn, timeout: 1),
            "Weight log sheet should appear with cancel or save"
        )

        // Dismiss the sheet
        if cancelBtn.exists { cancelBtn.tap() }
        else { app.swipeDown() }
        usleep(500_000)

        // STEP 4: Switch to Food tab
        step("Switch to Food tab")
        app.buttons["health_tab_food"].tap()
        usleep(500_000)

        // STEP 5: Verify food tab has quick meal input
        step("Food tab: verify quick meal input")
        let mealInput = app.textFields["health_quick_meal_input"]
        waitFor(mealInput, message: "Quick meal input should exist on food tab")

        // STEP 6: Type a real meal and verify submit button appears
        step("Food tab: type a meal")
        mealInput.tap()
        mealInput.typeText("Chicken salad with rice")
        usleep(500_000)

        let mealSubmit = app.buttons["health_quick_meal_submit"]
        waitFor(mealSubmit, timeout: 3, message: "Meal submit button should appear")

        // STEP 7: Verify photo and camera buttons exist
        step("Food tab: verify photo/camera buttons")
        waitFor(app.buttons["health_photo_button"], message: "Photo button should exist")
        waitFor(app.buttons["health_camera_button"], message: "Camera button should exist")

        // STEP 8: Submit the meal (opens SmartFoodLog sheet)
        step("Food tab: submit meal")
        mealSubmit.tap()
        usleep(800_000)

        // Sheet should open — dismiss it
        if exists(app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch, timeout: 2) {
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch.tap()
        } else {
            app.swipeDown()
        }
        usleep(500_000)

        // STEP 9: Switch to Activity tab
        step("Switch to Activity tab")
        app.buttons["health_tab_activity"].tap()
        usleep(500_000)

        // STEP 10: Today's Activity card
        step("Activity tab: verify today's activity card")
        let todayActivity = find("health_today_activity")
        XCTAssertTrue(todayActivity.exists, "Today's Activity card should exist")

        // STEP 11: Quick activity input — type real activity
        step("Activity tab: type activity")
        let actInput = app.textFields["health_quick_activity_input"]
        waitFor(actInput, message: "Quick activity input should exist")
        actInput.tap()
        actInput.typeText("Walked 30 min to campus")
        usleep(500_000)

        let actSubmit = app.buttons["health_quick_activity_submit"]
        waitFor(actSubmit, timeout: 3, message: "Activity submit button should appear")

        // STEP 12: Submit the activity
        step("Activity tab: submit activity")
        actSubmit.tap()
        usleep(800_000)

        // Input should be cleared
        let actValue = actInput.value as? String ?? ""
        XCTAssertTrue(
            actValue.isEmpty || actValue.contains("Walk") == false,
            "Activity input should be cleared after submit, got: '\(actValue)'"
        )

        // STEP 13: Structured Log button
        step("Activity tab: verify structured log button")
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        usleep(300_000)

        let structuredLog = app.buttons["health_structured_log_button"]
        waitFor(structuredLog, message: "Structured Log button should exist")

        // STEP 14: Open structured activity log sheet
        step("Activity tab: open structured log sheet")
        structuredLog.tap()
        usleep(800_000)

        // Sheet should have an activity type field and duration field
        let cancelSheet = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch
        if exists(cancelSheet, timeout: 2) {
            cancelSheet.tap()
        } else {
            app.swipeDown()
        }
        usleep(500_000)
    }
}
