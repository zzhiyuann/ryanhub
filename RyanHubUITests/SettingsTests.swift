import XCTest

final class SettingsTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        tapTab("tab_settings")
    }

    func testSettingsPageLoads() throws {
        let serverURL = app.textFields["settings_server_url"]
        XCTAssertTrue(waitForElement(serverURL), "Server URL field should exist")
    }

    func testServerURLFieldEditable() throws {
        let field = app.textFields["settings_server_url"]
        XCTAssertTrue(waitForElement(field))
        field.tap()
        // Should be able to interact
        XCTAssertTrue(field.exists)
    }

    func testPresetButtonsExist() throws {
        let localhost = app.buttons["settings_localhost_preset"]
        let reset = app.buttons["settings_reset_preset"]
        XCTAssertTrue(waitForElement(localhost), "Localhost preset should exist")
        XCTAssertTrue(waitForElement(reset), "Reset preset should exist")
    }

    func testTestConnectionButtonExists() throws {
        let testBtn = app.buttons["settings_test_connection"]
        XCTAssertTrue(waitForElement(testBtn), "Test connection button should exist")
    }

    func testSSHFieldsExist() throws {
        // Scroll down to find SSH fields
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        let host = app.textFields["settings_ssh_host"]
        let username = app.textFields["settings_ssh_username"]
        let password = app.secureTextFields["settings_ssh_password"]

        XCTAssertTrue(waitForElement(host), "SSH host field should exist")
        XCTAssertTrue(waitForElement(username), "SSH username field should exist")
        XCTAssertTrue(waitForElement(password), "SSH password field should exist")
    }

    func testAppearanceModeButtons() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()

        // Check that appearance buttons exist (system, dark, light)
        // The buttons use mode.rawValue for their IDs
        let systemBtn = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_appearance_'")).firstMatch
        XCTAssertTrue(waitForElement(systemBtn), "At least one appearance button should exist")
    }

    func testLanguageButtons() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        scrollView.swipeUp()

        let enBtn = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_language_'")).firstMatch
        XCTAssertTrue(waitForElement(enBtn), "At least one language button should exist")
    }

    func testVersionInfoDisplayed() throws {
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        scrollView.swipeUp()

        let version = app.otherElements["settings_version"]
        let versionText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS '1.'")).firstMatch
        XCTAssertTrue(
            waitForElement(version) || waitForElement(versionText),
            "Version info should be displayed"
        )
    }
}
