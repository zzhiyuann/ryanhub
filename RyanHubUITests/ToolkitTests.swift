import XCTest

/// Tests the Toolkit tab — desktop grid, menu bar, plugin navigation.
final class ToolkitTests: RyanHubUITestBase {

    func testToolkitDesktopGridAndAllCards() throws {
        step("Navigate to Toolkit tab")
        tapTab("tab_toolkit")

        // Make sure we're on home grid
        let homeBtn = app.buttons["toolkit_menu_home"]
        if homeBtn.waitForExistence(timeout: 2) {
            homeBtn.tap()
            usleep(400_000)
        }

        // STEP 1: Desktop grid visible
        step("Verify desktop grid")
        let grid = find("toolkit_desktop_grid")
        XCTAssertTrue(grid.exists, "Desktop grid should be visible")

        // STEP 2: All 5 plugin cards exist
        step("Verify all 5 plugin cards")
        let plugins = ["bookFactory", "fluent", "parking", "calendar", "health"]
        for plugin in plugins {
            let card = app.buttons["toolkit_card_\(plugin)"]
            waitFor(card, message: "Plugin card '\(plugin)' should exist in grid")
        }

        // STEP 3: Menu bar exists
        step("Verify menu bar")
        let menuBar = find("toolkit_menu_bar")
        XCTAssertTrue(menuBar.exists, "Menu bar should exist")
    }

    func testNavigateEachPluginViaCards() throws {
        tapTab("tab_toolkit")

        // Go home first
        let homeBtn = app.buttons["toolkit_menu_home"]
        if homeBtn.waitForExistence(timeout: 2) {
            homeBtn.tap()
            usleep(400_000)
        }

        // Book Factory
        step("Open Book Factory via card")
        app.buttons["toolkit_card_bookFactory"].tap()
        usleep(600_000)
        let bfSetup = find("bookfactory_server_setup")
        let bfLibrary = app.buttons["bookfactory_tab_library"]
        XCTAssertTrue(bfSetup.exists || bfLibrary.exists, "BookFactory should load")

        // Return home via menu
        step("Return to grid via home button")
        app.buttons["toolkit_menu_home"].tap()
        usleep(400_000)

        // Fluent
        step("Open Fluent via card")
        app.buttons["toolkit_card_fluent"].tap()
        usleep(600_000)
        waitFor(app.buttons["fluent_tab_dashboard"], message: "Fluent should show dashboard tab")

        // Switch to Parking via MENU BAR (not going home first)
        step("Switch to Parking via menu bar")
        let parkingMenu = app.buttons["toolkit_menu_parking"]
        waitFor(parkingMenu, message: "Parking menu item should exist")
        parkingMenu.tap()
        usleep(600_000)
        let todayStatus = find("parking_today_status")
        XCTAssertTrue(todayStatus.exists, "Parking today status should appear")

        // Switch to Calendar via menu bar
        step("Switch to Calendar via menu bar")
        app.buttons["toolkit_menu_calendar"].tap()
        usleep(600_000)
        let calEmpty = find("calendar_empty_state")
        let calToday = find("calendar_today_section")
        XCTAssertTrue(calEmpty.exists || calToday.exists, "Calendar should load")

        // Switch to Health via menu bar
        step("Switch to Health via menu bar")
        app.buttons["toolkit_menu_health"].tap()
        usleep(600_000)
        waitFor(app.buttons["health_tab_weight"], message: "Health weight tab should appear")

        // Return to home grid
        step("Return to home grid")
        app.buttons["toolkit_menu_home"].tap()
        usleep(400_000)
        let grid = find("toolkit_desktop_grid")
        XCTAssertTrue(grid.exists, "Desktop grid should reappear")
    }
}
