import XCTest

class RyanHubUITestBase: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Helper Methods

    /// Wait for an element to exist with a timeout.
    func waitForElement(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Tap a tab in the main tab bar.
    func tapTab(_ tabId: String) {
        let tab = app.buttons[tabId]
        XCTAssertTrue(waitForElement(tab), "Tab '\(tabId)' should exist")
        tab.tap()
    }

    /// Navigate to a toolkit plugin via the desktop grid.
    func navigateToPlugin(_ pluginRawValue: String) {
        tapTab("tab_toolkit")
        // First go to home grid
        let homeButton = app.buttons["toolkit_menu_home"]
        if homeButton.exists {
            homeButton.tap()
        }
        // Tap the plugin card
        let card = app.buttons["toolkit_card_\(pluginRawValue)"]
        XCTAssertTrue(waitForElement(card), "Plugin card '\(pluginRawValue)' should exist")
        card.tap()
    }

    /// Navigate to a toolkit plugin via menu bar.
    func tapToolkitMenu(_ pluginRawValue: String) {
        let menuItem = app.buttons["toolkit_menu_\(pluginRawValue)"]
        XCTAssertTrue(waitForElement(menuItem), "Menu item '\(pluginRawValue)' should exist")
        menuItem.tap()
    }
}
