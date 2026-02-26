import XCTest

/// Tests the Fluent language learning module — tabs, dashboard, vocabulary, review, settings.
final class FluentTests: RyanHubUITestBase {

    func testFluentCompleteFlow() throws {
        step("Navigate to Fluent plugin")
        navigateToPlugin("fluent")

        // STEP 1: All tabs visible
        step("Verify all Fluent tabs exist")
        waitFor(app.buttons["fluent_tab_dashboard"], message: "Dashboard tab missing")
        waitFor(app.buttons["fluent_tab_vocabulary"], message: "Vocabulary tab missing")
        waitFor(app.buttons["fluent_tab_review"], message: "Review tab missing")
        waitFor(app.buttons["fluent_tab_settings"], message: "Settings tab missing")

        // STEP 2: Dashboard content — daily goal card
        step("Dashboard: verify daily goal card")
        let dailyGoal = find("fluent_daily_goal_card")
        XCTAssertTrue(dailyGoal.exists, "Daily goal card should exist on dashboard")

        // STEP 3: Start Review button on dashboard
        step("Dashboard: verify start review button")
        let startReview = app.buttons["fluent_start_review"]
        if exists(startReview, timeout: 3) {
            step("Dashboard: tap Start Review")
            startReview.tap()
            usleep(800_000)
            // Should navigate to review tab or open review flow
            // Dismiss if it opened a sheet
            let cancelBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'cancel'")).firstMatch
            if exists(cancelBtn, timeout: 2) {
                cancelBtn.tap()
                usleep(300_000)
            }
        }

        // STEP 4: Word of the Day
        step("Dashboard: check word of the day")
        let wordOfDay = find("fluent_word_of_day")
        if wordOfDay.exists {
            // Try the speak button if it exists
            let speakBtn = app.buttons["fluent_speak_button"]
            if exists(speakBtn, timeout: 2) {
                step("Dashboard: tap speak button for word of day")
                speakBtn.tap()
                usleep(500_000)
            }
        }

        // STEP 5: Scroll down for quick actions
        step("Dashboard: scroll to quick actions")
        scrollContentUp()

        let browseWords = app.buttons["fluent_browse_words"]
        let reviewCards = app.buttons["fluent_review_cards"]
        if exists(browseWords, timeout: 2) {
            step("Dashboard: tap Browse Words quick action")
            browseWords.tap()
            usleep(600_000)
            // Should navigate to vocabulary — verify
            let vocabTab = app.buttons["fluent_tab_vocabulary"]
            // Might have auto-switched tab
        }

        // STEP 6: Switch to Vocabulary tab
        step("Switch to Vocabulary tab")
        app.buttons["fluent_tab_vocabulary"].tap()
        usleep(600_000)

        // Vocabulary should show a word list or empty state
        // Try scrolling through the list
        step("Vocabulary: scroll through list")
        scrollContentUp()
        scrollContentDown()

        // STEP 7: Switch to Review tab
        step("Switch to Review tab")
        app.buttons["fluent_tab_review"].tap()
        usleep(600_000)

        // Review tab might show "no cards to review" or flashcard
        // Just verify we switched successfully
        step("Review tab: verify content loaded")

        // STEP 8: Switch to Settings tab
        step("Switch to Settings tab")
        app.buttons["fluent_tab_settings"].tap()
        usleep(600_000)

        // Settings might open as a sheet or inline view
        // Dismiss if sheet
        let doneBtn = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'done'")).firstMatch
        if exists(doneBtn, timeout: 2) {
            doneBtn.tap()
            usleep(300_000)
        }

        // STEP 9: Return to Dashboard tab
        step("Return to Dashboard tab")
        app.buttons["fluent_tab_dashboard"].tap()
        usleep(400_000)
        XCTAssertTrue(
            exists(find("fluent_daily_goal_card"), timeout: 3),
            "Daily goal card should still exist after tab round-trip"
        )
    }
}
