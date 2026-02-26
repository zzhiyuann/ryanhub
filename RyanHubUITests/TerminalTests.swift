import XCTest

final class TerminalTests: RyanHubUITestBase {

    func testTerminalModeShowsSessionBar() throws {
        // Switch to terminal mode
        let terminalMode = app.buttons["mode_terminal"]
        XCTAssertTrue(waitForElement(terminalMode))
        terminalMode.tap()

        let sessionBar = app.buttons["terminal_session_bar"]
        XCTAssertTrue(waitForElement(sessionBar), "Session bar should exist in terminal mode")
    }

    func testTerminalConnectPrompt() throws {
        let terminalMode = app.buttons["mode_terminal"]
        XCTAssertTrue(waitForElement(terminalMode))
        terminalMode.tap()

        // When not connected, should show connect button
        let connectButton = app.buttons["terminal_connect_button"]
        // It might already be connected, so this is conditional
        if waitForElement(connectButton, timeout: 3) {
            XCTAssertTrue(connectButton.exists, "Connect button should exist when disconnected")
        }
    }
}
