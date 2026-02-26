import XCTest

/// Tests the Terminal mode — mode switching, session bar, connect prompt, session picker.
final class TerminalTests: RyanHubUITestBase {

    func testTerminalCompleteFlow() throws {
        // STEP 1: Make sure we're on chat tab first
        step("Ensure on Chat tab")
        tapTab("tab_chat")
        usleep(300_000)

        // STEP 2: Mode toggle should exist
        step("Verify mode toggle buttons")
        let chatMode = app.buttons["mode_chat"]
        let terminalMode = app.buttons["mode_terminal"]
        waitFor(chatMode, message: "Chat mode button should exist")
        waitFor(terminalMode, message: "Terminal mode button should exist")

        // STEP 3: Switch to Terminal mode
        step("Switch to Terminal mode")
        terminalMode.tap()
        usleep(800_000)

        // STEP 4: Session bar or connect button should appear
        step("Verify terminal UI elements")
        let sessionBar = app.buttons["terminal_session_bar"]
        let connectButton = app.buttons["terminal_connect_button"]
        XCTAssertTrue(
            exists(sessionBar, timeout: 3) || exists(connectButton, timeout: 1),
            "Terminal should show session bar or connect button"
        )

        // STEP 5: If connect button visible (not connected), test it
        if exists(connectButton, timeout: 2) {
            step("Terminal: tap Connect button")
            connectButton.tap()
            usleep(1_500_000)

            // Should attempt connection — might fail if no SSH server
            // Check for error state or session bar appearing
            let afterConnect = exists(sessionBar, timeout: 3) || exists(connectButton, timeout: 1)
            XCTAssertTrue(afterConnect, "Terminal should still show UI after connect attempt")
        }

        // STEP 6: If session bar visible (connected or session exists), test it
        if exists(sessionBar, timeout: 2) {
            step("Terminal: tap session bar for picker")
            sessionBar.tap()
            usleep(600_000)

            // Session picker should appear
            let sessionPicker = find("terminal_session_picker")
            if sessionPicker.exists {
                step("Session picker is visible")

                // New session button
                let newSession = app.buttons["terminal_new_session"]
                if exists(newSession, timeout: 2) {
                    step("Terminal: new session button exists")
                }

                // Dismiss the picker
                app.swipeDown()
                usleep(300_000)
            }
        }

        // STEP 7: Switch back to Chat mode
        step("Switch back to Chat mode")
        app.buttons["mode_chat"].tap()
        usleep(500_000)
        let chatInput = app.textFields["chat_input_field"]
        waitFor(chatInput, message: "Chat input should reappear after switching back from Terminal")

        // STEP 8: Switch to Terminal again (verify round-trip works)
        step("Switch to Terminal mode again")
        app.buttons["mode_terminal"].tap()
        usleep(500_000)
        XCTAssertTrue(
            exists(sessionBar, timeout: 3) || exists(connectButton, timeout: 1),
            "Terminal UI should appear again on second switch"
        )

        // STEP 9: Final — switch back to Chat for clean state
        step("Return to Chat mode")
        app.buttons["mode_chat"].tap()
        usleep(300_000)
    }
}
