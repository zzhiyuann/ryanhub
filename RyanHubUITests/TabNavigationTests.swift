import XCTest

final class TabNavigationTests: RyanHubUITestBase {

    func testAppLaunchesWithChatTab() throws {
        // App should start on chat tab
        let chatInput = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(chatInput), "Chat input should be visible on launch")
    }

    func testTabBarHasAllTabs() throws {
        XCTAssertTrue(app.buttons["tab_chat"].exists, "Chat tab should exist")
        XCTAssertTrue(app.buttons["tab_toolkit"].exists, "Toolkit tab should exist")
        XCTAssertTrue(app.buttons["tab_settings"].exists, "Settings tab should exist")
    }

    func testSwitchToToolkitTab() throws {
        tapTab("tab_toolkit")
        let grid = app.otherElements["toolkit_desktop_grid"]
        // Try scrollViews if otherElements doesn't work
        let gridAlt = app.scrollViews["toolkit_desktop_grid"]
        XCTAssertTrue(waitForElement(grid) || waitForElement(gridAlt), "Toolkit desktop grid should appear")
    }

    func testSwitchToSettingsTab() throws {
        tapTab("tab_settings")
        let serverURL = app.textFields["settings_server_url"]
        XCTAssertTrue(waitForElement(serverURL), "Settings server URL field should appear")
    }

    func testSwitchBackToChat() throws {
        tapTab("tab_toolkit")
        tapTab("tab_chat")
        let chatInput = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(chatInput), "Chat input should reappear")
    }

    func testChatTerminalModeToggle() throws {
        // Start in chat mode
        let chatMode = app.buttons["mode_chat"]
        let terminalMode = app.buttons["mode_terminal"]
        XCTAssertTrue(waitForElement(chatMode), "Chat mode button should exist")
        XCTAssertTrue(waitForElement(terminalMode), "Terminal mode button should exist")

        // Switch to terminal
        terminalMode.tap()
        // Terminal should show connect prompt or session bar
        let sessionBar = app.buttons["terminal_session_bar"]
        let connectButton = app.buttons["terminal_connect_button"]
        XCTAssertTrue(
            waitForElement(sessionBar) || waitForElement(connectButton),
            "Terminal view should show session bar or connect button"
        )

        // Switch back to chat
        chatMode.tap()
        let chatInput = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(chatInput), "Chat input should reappear after switching back")
    }
}
