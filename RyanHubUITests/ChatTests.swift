import XCTest

/// Tests the complete chat interface flow — input, send, mic, attachments.
final class ChatTests: RyanHubUITestBase {

    func testChatInterfaceFlow() throws {
        // Make sure we're on chat tab
        step("Navigate to chat tab")
        goToChat()

        // STEP 1: Verify empty state
        step("Verify empty state or messages area")
        let emptyState = find("chat_empty_state")
        let messagesArea = find("chat_messages_area")
        XCTAssertTrue(
            emptyState.exists || messagesArea.exists,
            "Should show empty state or messages area"
        )

        // STEP 2: Verify input field exists
        step("Verify chat input field")
        let input = app.textFields["chat_input_field"]
        waitFor(input, message: "Chat input field should exist")

        // STEP 3: Verify mic button shows when input is empty
        step("Verify mic button when empty")
        let mic = app.buttons["chat_mic_button"]
        waitFor(mic, message: "Mic button should show when input is empty")

        // STEP 4: Verify attachment button exists
        step("Verify attachment button")
        waitFor(app.buttons["chat_attach_button"], message: "Attachment button should exist")

        // STEP 5: Type text — send button should appear, mic should hide
        step("Type text and verify send button appears")
        input.tap()
        input.typeText("Hello from UI test")
        usleep(500_000)

        let send = app.buttons["chat_send_button"]
        waitFor(send, timeout: 3, message: "Send button should appear when text is entered")

        // STEP 6: Send the message
        step("Send message")
        send.tap()
        usleep(1_000_000)

        // Input should be cleared
        let inputValue = input.value as? String ?? ""
        XCTAssertTrue(
            inputValue.isEmpty || inputValue.contains("Message") || inputValue.contains("message"),
            "Input should be cleared after sending, got: '\(inputValue)'"
        )

        // STEP 7: The sent message should appear in the chat
        step("Verify sent message appears")
        let sentMessage = app.staticTexts["Hello from UI test"]
        XCTAssertTrue(
            exists(sentMessage, timeout: 5),
            "Sent message should appear in chat"
        )

        // STEP 8: Mic button should reappear after sending
        step("Verify mic button reappears")
        waitFor(mic, timeout: 3, message: "Mic button should reappear after message is sent")
    }

    func testClearTextRestoresMicButton() throws {
        goToChat()

        let input = app.textFields["chat_input_field"]
        waitFor(input)
        input.tap()
        input.typeText("Temporary text")
        usleep(300_000)

        // Send button should be visible
        let send = app.buttons["chat_send_button"]
        XCTAssertTrue(exists(send, timeout: 3), "Send button should show")

        // Clear the text using select all + delete
        step("Clear text")
        input.press(forDuration: 1.0)
        usleep(500_000)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 2) {
            selectAll.tap()
            usleep(200_000)
        }
        app.keys["delete"].tap()
        usleep(500_000)

        // Mic button should reappear
        let mic = app.buttons["chat_mic_button"]
        XCTAssertTrue(
            exists(mic, timeout: 3),
            "Mic button should reappear when text is cleared"
        )
    }
}
