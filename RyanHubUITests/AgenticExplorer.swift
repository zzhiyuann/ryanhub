import XCTest

/// Agentic explorer — runs exploration steps, logs everything it sees.
/// Claude Code writes steps, runs them, reads results, decides next step.
/// Inherits shared helpers from RyanHubUITestBase (scrollContentUp, safeLabel, etc.)
final class AgenticExplorer: RyanHubUITestBase {

    // MARK: - Full Exploration

    func testExplore() throws {
        // ==================== CHAT TAB ====================
        print("=== CHAT TAB ===")
        saveScreenshot("01_chat_launch")

        let chatInput = app.textFields["chat_input_field"]
        XCTAssertTrue(chatInput.waitForExistence(timeout: 5), "Chat input should exist on launch")

        let micBtn = app.buttons["chat_mic_button"]
        let attachBtn = app.buttons["chat_attach_button"]
        print("mic: \(micBtn.exists), attach: \(attachBtn.exists)")

        chatInput.tap()
        chatInput.typeText("Testing from agentic explorer!")
        usleep(500_000)

        let sendBtn = app.buttons["chat_send_button"]
        print("after typing - send: \(sendBtn.exists), mic: \(micBtn.exists)")
        XCTAssertTrue(sendBtn.exists, "Send button should appear after typing")
        saveScreenshot("02_chat_typed")

        sendBtn.tap()
        sleep(2)
        saveScreenshot("03_chat_sent")
        let sentMsg = app.staticTexts["Testing from agentic explorer!"]
        print("sent message visible: \(sentMsg.exists)")
        print("input cleared: \((chatInput.value as? String ?? "") == "Type a message...")")
        print("mic after send: \(micBtn.exists)")

        // ==================== TERMINAL MODE ====================
        print("=== TERMINAL MODE ===")
        let terminalMode = app.buttons["mode_terminal"]
        if terminalMode.exists {
            terminalMode.tap()
            sleep(1)
            saveScreenshot("04_terminal_mode")
            let sessionBar = app.buttons["terminal_session_bar"]
            let connectBtn = app.buttons["terminal_connect_button"]
            print("session bar: \(sessionBar.exists), connect: \(connectBtn.exists)")

            app.buttons["mode_chat"].tap()
            sleep(1)
        }

        // ==================== TOOLKIT TAB ====================
        print("=== TOOLKIT TAB ===")
        app.buttons["tab_toolkit"].tap()
        sleep(1)
        saveScreenshot("05_toolkit")

        let grid = app.scrollViews["toolkit_desktop_grid"]
        print("desktop grid: \(grid.exists)")

        let plugins = ["bookFactory", "fluent", "parking", "calendar", "health"]
        for p in plugins {
            let card = app.buttons["toolkit_card_\(p)"]
            print("card \(p): \(card.exists)")
        }

        // Check menu bar
        let menuBarOther = app.otherElements["toolkit_menu_bar"]
        print("menu bar (other): \(menuBarOther.exists)")

        for p in plugins {
            let menuItem = app.buttons["toolkit_menu_\(p)"]
            print("menu \(p): \(menuItem.exists)")
        }
        let homeMenuBtn = app.buttons["toolkit_menu_home"]
        print("menu home: \(homeMenuBtn.exists)")

        // ==================== HEALTH PLUGIN ====================
        print("=== HEALTH PLUGIN ===")
        navigateToPlugin("health")
        saveScreenshot("06_health_weight")

        let weightTab = app.buttons["health_tab_weight"]
        let foodTab = app.buttons["health_tab_food"]
        let activityTab = app.buttons["health_tab_activity"]
        print("weight: \(weightTab.exists), food: \(foodTab.exists), activity: \(activityTab.exists)")

        // Weight tab content
        let currentWeight = app.otherElements["health_current_weight"]
        let logWeightBtn = app.buttons["health_log_weight_button"]
        print("current weight card: \(currentWeight.exists)")
        print("log weight button: \(logWeightBtn.exists)")

        // Food tab
        foodTab.tap()
        sleep(1)
        saveScreenshot("07_health_food")

        let mealInput = app.textFields["health_quick_meal_input"]
        print("meal input: \(mealInput.exists)")

        if mealInput.exists {
            mealInput.tap()
            mealInput.typeText("Grilled chicken with brown rice and broccoli")
            usleep(500_000)

            let mealSubmit = app.buttons["health_quick_meal_submit"]
            print("meal submit visible: \(mealSubmit.exists)")
            saveScreenshot("08_health_meal_typed")

            // NOTE: NOT tapping submit — it opens SmartFoodLogView sheet which blocks everything
        }

        dismissKeyboard()

        // Photo and camera buttons
        let photoBtn = app.buttons["health_photo_button"]
        let cameraBtn = app.buttons["health_camera_button"]
        print("photo button: \(photoBtn.exists), camera button: \(cameraBtn.exists)")

        // Activity tab
        print("activity tab hittable: \(activityTab.isHittable)")
        activityTab.tap()
        sleep(1)
        saveScreenshot("10_health_activity")

        let actInput = app.textFields["health_quick_activity_input"]
        print("activity input: \(actInput.exists)")

        let todayActivityCard = app.otherElements["health_today_activity"]
        print("today activity card: \(todayActivityCard.exists)")

        if actInput.exists {
            actInput.tap()
            actInput.typeText("Morning jog 3km in 20 minutes")
            usleep(500_000)
            let actSubmit = app.buttons["health_quick_activity_submit"]
            print("activity submit: \(actSubmit.exists)")
            saveScreenshot("11_health_activity_typed")

            if actSubmit.exists {
                actSubmit.tap()
                sleep(1)
                saveScreenshot("12_health_activity_submitted")
                let actValue = actInput.value as? String ?? ""
                print("activity input after submit: '\(actValue)'")
            }
            dismissKeyboard()
        }

        // Scroll content area (not menu bar) to check structured log
        scrollContentUp()
        let structuredLog = app.buttons["health_structured_log_button"]
        print("structured log button: \(structuredLog.exists)")

        // ==================== PARKING PLUGIN ====================
        print("=== PARKING PLUGIN ===")
        navigateToPlugin("parking")
        saveScreenshot("13_parking")

        // Verify we're in Parking
        let parkingTodayStatus = app.otherElements["parking_today_status"]
        print("today status: \(parkingTodayStatus.exists)")

        let parkingPrevMonth = app.buttons["parking_prev_month"]
        let parkingNextMonth = app.buttons["parking_next_month"]
        let parkingMonthLabel = app.staticTexts["parking_month_label"]
        print("prev month (before scroll): \(parkingPrevMonth.exists)")

        // Scroll to calendar
        scrollContentUp()
        saveScreenshot("14_parking_calendar")

        let calendar = app.otherElements["parking_calendar"]
        print("calendar: \(calendar.exists)")
        print("prev month: \(parkingPrevMonth.exists), next month: \(parkingNextMonth.exists)")
        print("month label: \(parkingMonthLabel.exists), text: '\(safeLabel(parkingMonthLabel))'")

        if parkingNextMonth.exists {
            let original = safeLabel(parkingMonthLabel)
            parkingNextMonth.tap()
            usleep(500_000)
            print("after next: '\(safeLabel(parkingMonthLabel))' (was '\(original)')")
            saveScreenshot("15_parking_next_month")
            parkingPrevMonth.tap()
            usleep(500_000)
            print("after prev: '\(safeLabel(parkingMonthLabel))'")
        }

        // ==================== CALENDAR PLUGIN ====================
        print("=== CALENDAR PLUGIN ===")
        navigateToPlugin("calendar")
        saveScreenshot("16_calendar")

        let calEmpty = app.otherElements["calendar_empty_state"]
        let calToday = app.otherElements["calendar_today_section"]
        let syncBtn = app.buttons["calendar_sync_button"]
        print("empty state: \(calEmpty.exists), today section: \(calToday.exists), sync: \(syncBtn.exists)")

        if syncBtn.exists {
            syncBtn.tap()
            sleep(2)
            saveScreenshot("17_calendar_after_sync")
        }

        // ==================== FLUENT PLUGIN ====================
        print("=== FLUENT PLUGIN ===")
        navigateToPlugin("fluent")
        saveScreenshot("18_fluent")

        let dashTab = app.buttons["fluent_tab_dashboard"]
        let vocabTab = app.buttons["fluent_tab_vocabulary"]
        let reviewTab = app.buttons["fluent_tab_review"]
        let settingsFluentTab = app.buttons["fluent_tab_settings"]
        print("dashboard: \(dashTab.exists), vocab: \(vocabTab.exists)")
        print("review: \(reviewTab.exists), settings: \(settingsFluentTab.exists)")

        let dailyGoal = app.otherElements["fluent_daily_goal_card"]
        print("daily goal card: \(dailyGoal.exists)")

        if vocabTab.exists {
            vocabTab.tap()
            sleep(1)
            saveScreenshot("19_fluent_vocab")
        }
        if reviewTab.exists {
            reviewTab.tap()
            sleep(1)
            saveScreenshot("20_fluent_review")
        }

        // ==================== BOOK FACTORY ====================
        print("=== BOOK FACTORY ===")
        navigateToPlugin("bookFactory")
        saveScreenshot("21_bookfactory")

        let setup = app.otherElements["bookfactory_server_setup"]
        let library = app.buttons["bookfactory_tab_library"]
        print("server setup: \(setup.exists), library tab: \(library.exists)")

        if setup.exists {
            let urlField = app.textFields["bookfactory_server_url"]
            let userField = app.textFields["bookfactory_username"]
            let passField = app.secureTextFields["bookfactory_password"]
            let bfConnectBtn = app.buttons["bookfactory_connect_button"]
            print("url: \(urlField.exists), user: \(userField.exists), pass: \(passField.exists)")
            print("connect: \(bfConnectBtn.exists), enabled: \(bfConnectBtn.isEnabled)")
        }

        // ==================== SETTINGS TAB ====================
        print("=== SETTINGS TAB ===")
        app.buttons["tab_settings"].tap()
        sleep(1)
        saveScreenshot("22_settings")

        let serverURL = app.textFields["settings_server_url"]
        print("server url: \(serverURL.exists), value: '\(serverURL.value ?? "nil")'")

        let localhostPreset = app.buttons["settings_localhost_preset"]
        let resetPreset = app.buttons["settings_reset_preset"]
        let testConn = app.buttons["settings_test_connection"]
        print("localhost: \(localhostPreset.exists), reset: \(resetPreset.exists), test: \(testConn.exists)")

        if testConn.exists {
            testConn.tap()
            sleep(2)
            saveScreenshot("23_settings_test_connection")
        }

        // Scroll to SSH section
        scrollContentUp()
        saveScreenshot("24_settings_ssh")

        let sshHost = app.textFields["settings_ssh_host"]
        let sshUser = app.textFields["settings_ssh_username"]
        print("ssh host: \(sshHost.exists), ssh user: \(sshUser.exists)")

        // Scroll to appearance
        scrollContentUp()
        saveScreenshot("25_settings_appearance")

        let appearanceButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'settings_appearance_'"))
        print("appearance buttons count: \(appearanceButtons.count)")

        // ==================== BACK TO CHAT ====================
        print("=== BACK TO CHAT ===")
        app.buttons["tab_chat"].tap()
        sleep(1)
        saveScreenshot("26_back_to_chat")

        let chatInputFinal = app.textFields["chat_input_field"]
        print("chat input exists: \(chatInputFinal.exists)")

        print("=== EXPLORATION COMPLETE ===")
    }
}
