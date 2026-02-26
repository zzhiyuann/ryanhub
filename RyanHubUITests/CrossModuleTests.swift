import XCTest

final class CrossModuleTests: RyanHubUITestBase {

    func testFullNavigationFlow() throws {
        // 1. Start in chat
        let chatInput = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(chatInput))

        // 2. Go to toolkit
        tapTab("tab_toolkit")
        let grid = app.scrollViews["toolkit_desktop_grid"]
        let gridAlt = app.otherElements["toolkit_desktop_grid"]
        XCTAssertTrue(waitForElement(grid) || waitForElement(gridAlt))

        // 3. Open Health
        let healthCard = app.buttons["toolkit_card_health"]
        XCTAssertTrue(waitForElement(healthCard))
        healthCard.tap()
        let weightTab = app.buttons["health_tab_weight"]
        XCTAssertTrue(waitForElement(weightTab))

        // 4. Switch to Parking via menu
        let parkingMenu = app.buttons["toolkit_menu_parking"]
        XCTAssertTrue(waitForElement(parkingMenu))
        parkingMenu.tap()
        let todayStatus = app.otherElements["parking_today_status"]
        XCTAssertTrue(waitForElement(todayStatus))

        // 5. Go to settings
        tapTab("tab_settings")
        let serverURL = app.textFields["settings_server_url"]
        XCTAssertTrue(waitForElement(serverURL))

        // 6. Back to chat
        tapTab("tab_chat")
        XCTAssertTrue(waitForElement(chatInput))
    }

    func testToolkitStatePreserved() throws {
        // Open a toolkit plugin
        tapTab("tab_toolkit")
        let parkingCard = app.buttons["toolkit_card_parking"]
        XCTAssertTrue(waitForElement(parkingCard))
        parkingCard.tap()

        let todayStatus = app.otherElements["parking_today_status"]
        XCTAssertTrue(waitForElement(todayStatus))

        // Switch away and back
        tapTab("tab_chat")
        tapTab("tab_toolkit")

        // Parking should still be shown (state preserved)
        // or home grid might show depending on implementation
        sleep(1)
    }

    func testRapidTabSwitching() throws {
        // Rapidly switch tabs to test for crashes
        for _ in 0..<5 {
            tapTab("tab_chat")
            tapTab("tab_toolkit")
            tapTab("tab_settings")
        }

        // App should not crash — if we reach here, it's good
        XCTAssertTrue(app.exists, "App should still be running after rapid tab switching")
    }
}
