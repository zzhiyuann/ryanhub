import XCTest

final class BookFactoryTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        navigateToPlugin("bookFactory")
    }

    func testBookFactoryViewLoads() throws {
        // Should show server setup or main content
        let serverSetup = app.otherElements["bookfactory_server_setup"]
        let libraryTab = app.buttons["bookfactory_tab_library"]
        XCTAssertTrue(
            waitForElement(serverSetup) || waitForElement(libraryTab),
            "BookFactory should show setup or library"
        )
    }

    func testServerSetupFieldsExist() throws {
        let serverSetup = app.otherElements["bookfactory_server_setup"]
        if waitForElement(serverSetup, timeout: 3) {
            let urlField = app.textFields["bookfactory_server_url"]
            let usernameField = app.textFields["bookfactory_username"]
            let passwordField = app.secureTextFields["bookfactory_password"]
            let connectButton = app.buttons["bookfactory_connect_button"]

            XCTAssertTrue(waitForElement(urlField), "Server URL field should exist")
            XCTAssertTrue(waitForElement(usernameField), "Username field should exist")
            XCTAssertTrue(waitForElement(passwordField), "Password field should exist")
            XCTAssertTrue(waitForElement(connectButton), "Connect button should exist")
        }
    }

    func testConnectButtonDisabledWhenEmpty() throws {
        let serverSetup = app.otherElements["bookfactory_server_setup"]
        if waitForElement(serverSetup, timeout: 3) {
            let connectButton = app.buttons["bookfactory_connect_button"]
            XCTAssertTrue(waitForElement(connectButton))
            XCTAssertFalse(connectButton.isEnabled, "Connect should be disabled when fields are empty")
        }
    }
}
