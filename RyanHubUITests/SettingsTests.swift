import XCTest

/// Tests the Settings page — server config, SSH, appearance, language, about.
final class SettingsTests: RyanHubUITestBase {

    func testSettingsFullFlow() throws {
        step("Navigate to Settings tab")
        tapTab("tab_settings")

        // STEP 1: Server URL field
        step("Verify server URL field")
        let serverURL = app.textFields["settings_server_url"]
        waitFor(serverURL, message: "Server URL field should exist")

        // STEP 2: Preset buttons
        step("Verify preset buttons")
        waitFor(app.buttons["settings_localhost_preset"], message: "Localhost preset should exist")
        waitFor(app.buttons["settings_reset_preset"], message: "Reset preset should exist")

        // STEP 3: Test Connection button
        step("Verify Test Connection button")
        waitFor(app.buttons["settings_test_connection"], message: "Test Connection button should exist")

        // STEP 4: Tap Localhost preset and verify URL changes
        step("Tap Localhost preset")
        app.buttons["settings_localhost_preset"].tap()
        usleep(300_000)
        let urlValue = serverURL.value as? String ?? ""
        XCTAssertTrue(urlValue.contains("localhost") || urlValue.contains("ws://"), "URL should contain localhost after preset tap, got: '\(urlValue)'")

        // STEP 5: Scroll to SSH section
        step("Scroll to SSH section")
        let scrollView = app.scrollViews.firstMatch
        scrollView.swipeUp()
        usleep(300_000)

        // STEP 6: SSH fields
        step("Verify SSH fields")
        let sshHost = find("settings_ssh_host")
        XCTAssertTrue(sshHost.exists, "SSH host field should exist")
        let sshUsername = find("settings_ssh_username")
        XCTAssertTrue(sshUsername.exists, "SSH username field should exist")
        let sshPassword = find("settings_ssh_password")
        XCTAssertTrue(sshPassword.exists, "SSH password field should exist")

        // STEP 7: Test SSH button
        step("Verify Test SSH button")
        waitFor(app.buttons["settings_test_ssh"], message: "Test SSH button should exist")

        // STEP 8: Scroll to Appearance section
        step("Scroll to appearance section")
        scrollView.swipeUp()
        usleep(300_000)

        // STEP 9: Appearance mode buttons
        step("Verify appearance mode buttons")
        let appearanceButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_appearance_'"))
        XCTAssertGreaterThanOrEqual(appearanceButtons.count, 2, "Should have at least 2 appearance buttons")

        // STEP 10: Tap a different appearance mode
        step("Tap Dark appearance mode")
        let darkButton = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'dark' OR identifier CONTAINS 'Dark'")).firstMatch
        if darkButton.waitForExistence(timeout: 2) {
            darkButton.tap()
            usleep(500_000)
        }

        // STEP 11: Language buttons
        step("Verify language buttons")
        let langButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_language_'"))
        XCTAssertGreaterThanOrEqual(langButtons.count, 2, "Should have at least 2 language buttons")

        // STEP 12: Scroll to About section
        step("Scroll to About section")
        scrollView.swipeUp()
        usleep(300_000)

        // STEP 13: Version and Build info
        step("Verify version/build info")
        // These might be HStack containers, not text — check via find()
        let version = find("settings_version")
        XCTAssertTrue(version.exists, "Version row should exist")
    }
}
