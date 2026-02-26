import XCTest

final class ToolkitTests: RyanHubUITestBase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        tapTab("tab_toolkit")
    }

    func testToolkitDesktopGridShows() throws {
        let grid = app.scrollViews["toolkit_desktop_grid"]
        let gridAlt = app.otherElements["toolkit_desktop_grid"]
        XCTAssertTrue(
            waitForElement(grid) || waitForElement(gridAlt),
            "Desktop grid should be visible"
        )
    }

    func testAllPluginCardsExist() throws {
        let plugins = ["bookFactory", "fluent", "parking", "calendar", "health"]
        for plugin in plugins {
            let card = app.buttons["toolkit_card_\(plugin)"]
            XCTAssertTrue(waitForElement(card), "Plugin card '\(plugin)' should exist")
        }
    }

    func testMenuBarExists() throws {
        let menuBar = app.otherElements["toolkit_menu_bar"]
        XCTAssertTrue(waitForElement(menuBar), "Menu bar should exist")
    }

    func testNavigateToBookFactory() throws {
        let card = app.buttons["toolkit_card_bookFactory"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        // Should show either server setup or main content
        let serverSetup = app.otherElements["bookfactory_server_setup"]
        let libraryTab = app.buttons["bookfactory_tab_library"]
        XCTAssertTrue(
            waitForElement(serverSetup) || waitForElement(libraryTab),
            "BookFactory should show setup or library tab"
        )
    }

    func testNavigateToFluent() throws {
        let card = app.buttons["toolkit_card_fluent"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        let dashboard = app.buttons["fluent_tab_dashboard"]
        XCTAssertTrue(waitForElement(dashboard), "Fluent dashboard tab should appear")
    }

    func testNavigateToParking() throws {
        let card = app.buttons["toolkit_card_parking"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        let todayStatus = app.otherElements["parking_today_status"]
        XCTAssertTrue(waitForElement(todayStatus), "Parking today status should appear")
    }

    func testNavigateToCalendar() throws {
        let card = app.buttons["toolkit_card_calendar"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        // Calendar should show empty state or events
        let emptyState = app.otherElements["calendar_empty_state"]
        let todaySection = app.otherElements["calendar_today_section"]
        XCTAssertTrue(
            waitForElement(emptyState) || waitForElement(todaySection),
            "Calendar should show empty state or today section"
        )
    }

    func testNavigateToHealth() throws {
        let card = app.buttons["toolkit_card_health"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        let weightTab = app.buttons["health_tab_weight"]
        XCTAssertTrue(waitForElement(weightTab), "Health weight tab should appear")
    }

    func testMenuBarNavigation() throws {
        // First open a plugin
        let card = app.buttons["toolkit_card_fluent"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        // Use menu bar to switch to parking
        let parkingMenu = app.buttons["toolkit_menu_parking"]
        XCTAssertTrue(waitForElement(parkingMenu))
        parkingMenu.tap()

        let todayStatus = app.otherElements["parking_today_status"]
        XCTAssertTrue(waitForElement(todayStatus), "Should navigate to parking via menu bar")
    }

    func testReturnToHomeGrid() throws {
        // Navigate to a plugin
        let card = app.buttons["toolkit_card_parking"]
        XCTAssertTrue(waitForElement(card))
        card.tap()

        // Press home in menu bar
        let homeButton = app.buttons["toolkit_menu_home"]
        XCTAssertTrue(waitForElement(homeButton))
        homeButton.tap()

        // Desktop grid should reappear
        let grid = app.scrollViews["toolkit_desktop_grid"]
        let gridAlt = app.otherElements["toolkit_desktop_grid"]
        XCTAssertTrue(
            waitForElement(grid) || waitForElement(gridAlt),
            "Desktop grid should reappear after pressing home"
        )
    }
}
