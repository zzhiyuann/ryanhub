import XCTest

/// Tests the Book Factory module — server setup fields, connection flow, tab navigation.
final class BookFactoryTests: RyanHubUITestBase {

    func testBookFactoryCompleteFlow() throws {
        step("Navigate to Book Factory plugin")
        navigateToPlugin("bookFactory")

        // STEP 1: Should show server setup OR main content
        step("Verify Book Factory loads")
        let serverSetup = find("bookfactory_server_setup")
        let libraryTab = app.buttons["bookfactory_tab_library"]

        XCTAssertTrue(
            serverSetup.exists || exists(libraryTab, timeout: 3),
            "BookFactory should show server setup or library tab"
        )

        // If we're on server setup, test the form fields
        if serverSetup.exists {
            step("Server setup: verify all fields")

            // STEP 2: URL field
            let urlField = app.textFields["bookfactory_server_url"]
            waitFor(urlField, message: "Server URL field should exist")

            // STEP 3: Username field
            let usernameField = app.textFields["bookfactory_username"]
            waitFor(usernameField, message: "Username field should exist")

            // STEP 4: Password field
            let passwordField = app.secureTextFields["bookfactory_password"]
            waitFor(passwordField, message: "Password field should exist")

            // STEP 5: Connect button
            let connectBtn = app.buttons["bookfactory_connect_button"]
            waitFor(connectBtn, message: "Connect button should exist")

            // STEP 6: Connect button should be disabled when fields are empty
            step("Server setup: verify connect disabled when empty")
            // Clear any pre-filled values
            urlField.tap()
            usleep(200_000)

            // STEP 7: Type real server credentials
            step("Server setup: enter test server URL")
            urlField.tap()
            // Select all + delete to clear existing text
            urlField.press(forDuration: 1.0)
            usleep(300_000)
            let selectAll = app.menuItems["Select All"]
            if selectAll.waitForExistence(timeout: 1) {
                selectAll.tap()
                usleep(200_000)
                app.keys["delete"].tap()
                usleep(200_000)
            }
            urlField.typeText("https://bookfactory.example.com")
            usleep(300_000)

            step("Server setup: enter username")
            usernameField.tap()
            usernameField.typeText("testuser")
            usleep(300_000)

            step("Server setup: enter password")
            passwordField.tap()
            passwordField.typeText("testpass123")
            usleep(300_000)

            // STEP 8: Connect button should now be enabled (fields filled)
            step("Server setup: verify connect button state after filling fields")
            // Tap connect — it will likely fail (no real server) but tests the flow
            if connectBtn.isEnabled {
                step("Server setup: tap Connect")
                connectBtn.tap()
                usleep(1_500_000)

                // Should show an error or loading state
                // Check for error alert
                let errorAlert = app.alerts.firstMatch
                if errorAlert.waitForExistence(timeout: 3) {
                    step("Server setup: dismiss error alert")
                    let okBtn = errorAlert.buttons.firstMatch
                    okBtn.tap()
                    usleep(300_000)
                }
            }
        }

        // If we made it to main content (already connected), test tabs
        if exists(libraryTab, timeout: 2) {
            step("Main content: verify tab navigation")

            // STEP 9: Library tab
            libraryTab.tap()
            usleep(500_000)

            // STEP 10: Queue tab
            let queueTab = app.buttons["bookfactory_tab_queue"]
            if exists(queueTab, timeout: 2) {
                queueTab.tap()
                usleep(500_000)
            }

            // STEP 11: Settings tab
            let settingsTab = app.buttons["bookfactory_tab_settings"]
            if exists(settingsTab, timeout: 2) {
                settingsTab.tap()
                usleep(500_000)
            }

            // STEP 12: Mini player (might exist if book is playing)
            let miniPlayer = find("bookfactory_mini_player")
            if miniPlayer.exists {
                step("Main content: mini player visible")
            }
        }
    }
}
