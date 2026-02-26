import XCTest

class RyanHubUITestBase: XCTestCase {
    // Shared app instance — launch only once per test class
    static var app: XCUIApplication!
    static var isLaunched = false

    var app: XCUIApplication { Self.app }

    override class func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        isLaunched = true
    }

    override class func tearDown() {
        app = nil
        isLaunched = false
        super.tearDown()
    }

    override func setUpWithError() throws {
        // Continue after failure so we see ALL failures, not just the first
        continueAfterFailure = true
    }

    // MARK: - Helpers

    /// Wait for an element to exist with a timeout. Returns the element if found.
    @discardableResult
    func waitFor(_ element: XCUIElement, timeout: TimeInterval = 5, message: String = "") -> XCUIElement {
        let exists = element.waitForExistence(timeout: timeout)
        XCTAssertTrue(exists, message.isEmpty ? "Element should exist: \(element)" : message)
        return element
    }

    /// Check if element exists without asserting.
    func exists(_ element: XCUIElement, timeout: TimeInterval = 3) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    /// Find an element by accessibility ID, trying multiple element types.
    func find(_ id: String, timeout: TimeInterval = 5) -> XCUIElement {
        // Try buttons first (most common interactive element)
        let button = app.buttons[id]
        if button.waitForExistence(timeout: timeout) { return button }

        // Try text fields
        let textField = app.textFields[id]
        if textField.waitForExistence(timeout: 1) { return textField }

        // Try secure text fields
        let secureField = app.secureTextFields[id]
        if secureField.waitForExistence(timeout: 1) { return secureField }

        // Try static texts
        let text = app.staticTexts[id]
        if text.waitForExistence(timeout: 1) { return text }

        // Try other elements (VStack, HStack, etc.)
        let other = app.otherElements[id]
        if other.waitForExistence(timeout: 1) { return other }

        // Try scroll views
        let scroll = app.scrollViews[id]
        if scroll.waitForExistence(timeout: 1) { return scroll }

        // Return the button query as fallback (will fail assertion)
        return button
    }

    /// Tap a main tab bar button.
    func tapTab(_ tabId: String) {
        let tab = app.buttons[tabId]
        waitFor(tab, message: "Tab '\(tabId)' should exist")
        tab.tap()
        // Small wait for animation
        usleep(300_000)
    }

    /// Navigate to a toolkit plugin via the desktop grid.
    func navigateToPlugin(_ pluginRawValue: String) {
        tapTab("tab_toolkit")
        // Go to home grid first
        let homeButton = app.buttons["toolkit_menu_home"]
        if homeButton.waitForExistence(timeout: 2) {
            homeButton.tap()
            usleep(400_000)
        }
        // Tap the plugin card
        let card = app.buttons["toolkit_card_\(pluginRawValue)"]
        waitFor(card, message: "Plugin card '\(pluginRawValue)' should exist")
        card.tap()
        usleep(500_000)
    }

    /// Return to the chat tab.
    func goToChat() {
        tapTab("tab_chat")
    }

    /// Log a test step for visibility.
    func step(_ description: String) {
        XCTContext.runActivity(named: description) { _ in }
    }
}
