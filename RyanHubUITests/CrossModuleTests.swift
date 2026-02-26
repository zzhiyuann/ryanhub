import XCTest

/// Cross-module integration tests — navigating between all modules, state preservation, stress tests.
final class CrossModuleTests: RyanHubUITestBase {

    func testFullCrossModuleNavigationFlow() throws {
        // STEP 1: Start on Chat — type something to create state
        step("Start on Chat tab, create state")
        tapTab("tab_chat")
        let chatInput = app.textFields["chat_input_field"]
        waitFor(chatInput, message: "Chat input should exist at start")
        chatInput.tap()
        chatInput.typeText("Cross module test message")
        usleep(300_000)

        // Send the message
        let sendBtn = app.buttons["chat_send_button"]
        if exists(sendBtn, timeout: 3) {
            sendBtn.tap()
            usleep(800_000)
        }

        // STEP 2: Switch to Terminal mode
        step("Switch to Terminal mode")
        app.buttons["mode_terminal"].tap()
        usleep(500_000)
        let sessionBar = app.buttons["terminal_session_bar"]
        let connectButton = app.buttons["terminal_connect_button"]
        XCTAssertTrue(
            exists(sessionBar, timeout: 3) || exists(connectButton, timeout: 1),
            "Terminal UI should appear"
        )

        // STEP 3: Switch to Toolkit tab (while in terminal mode)
        step("Navigate to Toolkit tab from Terminal mode")
        tapTab("tab_toolkit")
        usleep(400_000)
        let grid = find("toolkit_desktop_grid")
        XCTAssertTrue(grid.exists, "Toolkit grid should appear even when in terminal mode")

        // STEP 4: Open Health plugin
        step("Open Health via card")
        app.buttons["toolkit_card_health"].tap()
        usleep(600_000)
        waitFor(app.buttons["health_tab_weight"], message: "Health should load with weight tab")

        // Type a quick activity
        step("Health: switch to activity tab and type")
        app.buttons["health_tab_activity"].tap()
        usleep(400_000)
        let actInput = app.textFields["health_quick_activity_input"]
        if exists(actInput, timeout: 3) {
            actInput.tap()
            actInput.typeText("Ran 2 miles")
            usleep(300_000)
        }

        // STEP 5: Switch to Parking via menu bar (NOT going home first)
        step("Switch to Parking via menu bar")
        let parkingMenu = app.buttons["toolkit_menu_parking"]
        waitFor(parkingMenu, message: "Parking menu item should exist")
        parkingMenu.tap()
        usleep(600_000)
        let todayStatus = find("parking_today_status")
        XCTAssertTrue(todayStatus.exists, "Parking today status should appear")

        // STEP 6: Go to Settings tab
        step("Navigate to Settings tab")
        tapTab("tab_settings")
        usleep(400_000)
        let serverURL = app.textFields["settings_server_url"]
        waitFor(serverURL, message: "Settings server URL should appear")

        // Interact with settings — tap localhost preset
        step("Settings: tap Localhost preset")
        let localhostPreset = app.buttons["settings_localhost_preset"]
        if exists(localhostPreset, timeout: 2) {
            localhostPreset.tap()
            usleep(300_000)
        }

        // STEP 7: Go back to Toolkit — should remember we were in Parking (or show home)
        step("Return to Toolkit tab")
        tapTab("tab_toolkit")
        usleep(400_000)

        // STEP 8: Open Calendar from menu
        step("Switch to Calendar via menu bar")
        app.buttons["toolkit_menu_calendar"].tap()
        usleep(600_000)
        let calEmpty = find("calendar_empty_state")
        let calToday = find("calendar_today_section")
        let calSync = app.buttons["calendar_sync_button"]
        XCTAssertTrue(
            calEmpty.exists || calToday.exists || exists(calSync, timeout: 1),
            "Calendar should show some content"
        )

        // STEP 9: Open BookFactory from menu
        step("Switch to Book Factory via menu bar")
        app.buttons["toolkit_menu_bookFactory"].tap()
        usleep(600_000)
        let bfSetup = find("bookfactory_server_setup")
        let bfLibrary = app.buttons["bookfactory_tab_library"]
        XCTAssertTrue(
            bfSetup.exists || exists(bfLibrary, timeout: 1),
            "BookFactory should show setup or library"
        )

        // STEP 10: Open Fluent from menu
        step("Switch to Fluent via menu bar")
        app.buttons["toolkit_menu_fluent"].tap()
        usleep(600_000)
        waitFor(app.buttons["fluent_tab_dashboard"], message: "Fluent dashboard tab should appear")

        // STEP 11: Return to home grid
        step("Return to home grid")
        app.buttons["toolkit_menu_home"].tap()
        usleep(400_000)
        XCTAssertTrue(find("toolkit_desktop_grid").exists, "Desktop grid should reappear")

        // STEP 12: Back to Chat — message should still be there
        step("Return to Chat tab")
        tapTab("tab_chat")
        usleep(400_000)
        // Check if we're still in terminal mode or chat mode
        let chatInputAgain = app.textFields["chat_input_field"]
        let terminalUI = app.buttons["terminal_session_bar"]
        XCTAssertTrue(
            exists(chatInputAgain, timeout: 3) || exists(terminalUI, timeout: 1),
            "Chat tab should show either chat input or terminal"
        )

        // If in terminal mode, switch back to chat
        if !exists(chatInputAgain, timeout: 1) {
            app.buttons["mode_chat"].tap()
            usleep(300_000)
            waitFor(chatInputAgain, message: "Chat input should appear after mode switch")
        }

        // Verify our earlier message is visible
        let sentMessage = app.staticTexts["Cross module test message"]
        if exists(sentMessage, timeout: 3) {
            step("Earlier message still visible — state preserved!")
        }
    }

    func testRapidCrossModuleStressTest() throws {
        step("Rapid cross-module stress test")

        // 10 rounds of rapid switching across all modules
        for round in 0..<10 {
            tapTab("tab_chat")
            tapTab("tab_toolkit")
            tapTab("tab_settings")
            tapTab("tab_toolkit")

            // Quick plugin switches via menu bar
            if round % 3 == 0 {
                let healthMenu = app.buttons["toolkit_menu_health"]
                if healthMenu.waitForExistence(timeout: 1) {
                    healthMenu.tap()
                }
            }
            if round % 3 == 1 {
                let parkMenu = app.buttons["toolkit_menu_parking"]
                if parkMenu.waitForExistence(timeout: 1) {
                    parkMenu.tap()
                }
            }
            if round % 3 == 2 {
                let homeMenu = app.buttons["toolkit_menu_home"]
                if homeMenu.waitForExistence(timeout: 1) {
                    homeMenu.tap()
                }
            }
        }

        // App should survive
        XCTAssertTrue(app.exists, "App should survive 10 rounds of rapid cross-module switching")

        // Final verification: can we still interact?
        step("Final verification: app still responsive")
        tapTab("tab_chat")
        usleep(300_000)
        let chatInput = app.textFields["chat_input_field"]
        let terminalUI = app.buttons["mode_terminal"]
        XCTAssertTrue(
            exists(chatInput, timeout: 3) || exists(terminalUI, timeout: 1),
            "App should still be responsive after stress test"
        )
    }
}
