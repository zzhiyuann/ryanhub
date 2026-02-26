import XCTest

/// Tests the main tab bar navigation and chat/terminal mode switching.
/// Runs as a single flow — app launches once, all navigation tested sequentially.
final class TabNavigationTests: RyanHubUITestBase {

    func testCompleteTabNavigationFlow() throws {
        // STEP 1: App should start on chat tab with input field visible
        step("Verify app launches on chat tab")
        let chatInput = app.textFields["chat_input_field"]
        waitFor(chatInput, message: "Chat input should be visible on launch")

        // STEP 2: All three tab buttons should exist
        step("Verify all tab bar buttons exist")
        waitFor(app.buttons["tab_chat"], message: "Chat tab button missing")
        waitFor(app.buttons["tab_toolkit"], message: "Toolkit tab button missing")
        waitFor(app.buttons["tab_settings"], message: "Settings tab button missing")

        // STEP 3: Chat/Terminal mode toggle buttons should exist
        step("Verify chat/terminal mode toggle")
        waitFor(app.buttons["mode_chat"], message: "Chat mode button missing")
        waitFor(app.buttons["mode_terminal"], message: "Terminal mode button missing")

        // STEP 4: Switch to Terminal mode
        step("Switch to Terminal mode")
        app.buttons["mode_terminal"].tap()
        usleep(500_000)
        let sessionBar = app.buttons["terminal_session_bar"]
        let connectButton = app.buttons["terminal_connect_button"]
        XCTAssertTrue(
            exists(sessionBar) || exists(connectButton),
            "Terminal should show session bar or connect button"
        )

        // STEP 5: Switch back to Chat mode
        step("Switch back to Chat mode")
        app.buttons["mode_chat"].tap()
        usleep(500_000)
        waitFor(app.textFields["chat_input_field"], message: "Chat input should reappear")

        // STEP 6: Navigate to Toolkit tab
        step("Navigate to Toolkit tab")
        tapTab("tab_toolkit")
        let grid = find("toolkit_desktop_grid")
        XCTAssertTrue(grid.exists, "Toolkit desktop grid should appear")

        // STEP 7: Navigate to Settings tab
        step("Navigate to Settings tab")
        tapTab("tab_settings")
        waitFor(app.textFields["settings_server_url"], message: "Settings server URL should appear")

        // STEP 8: Return to Chat tab
        step("Return to Chat tab")
        tapTab("tab_chat")
        waitFor(app.textFields["chat_input_field"], message: "Chat input should reappear on return")

        // STEP 9: Rapid tab switching (crash test)
        step("Rapid tab switching - crash test")
        for i in 0..<5 {
            tapTab("tab_toolkit")
            tapTab("tab_settings")
            tapTab("tab_chat")
            if i == 4 {
                XCTAssertTrue(app.exists, "App should survive rapid tab switching")
            }
        }
    }
}
