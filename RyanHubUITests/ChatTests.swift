import XCTest

final class ChatTests: RyanHubUITestBase {

    func testChatEmptyStateShown() throws {
        // On fresh launch with no messages, empty state should show
        let emptyState = app.otherElements["chat_empty_state"]
        // Empty state might be in staticTexts or other containers
        let welcomeText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Ryan Hub'")).firstMatch
        // Either the empty state identifier or the welcome text should exist
        XCTAssertTrue(
            waitForElement(emptyState) || waitForElement(welcomeText),
            "Empty state or welcome text should be visible"
        )
    }

    func testChatInputFieldExists() throws {
        let input = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(input), "Chat input field should exist")
    }

    func testMicButtonShowsWhenEmpty() throws {
        let mic = app.buttons["chat_mic_button"]
        XCTAssertTrue(waitForElement(mic), "Mic button should show when input is empty")
    }

    func testSendButtonAppearsWhenTyping() throws {
        let input = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(input))
        input.tap()
        input.typeText("Hello test message")

        let send = app.buttons["chat_send_button"]
        XCTAssertTrue(waitForElement(send, timeout: 3), "Send button should appear when text is entered")
    }

    func testSendButtonDisappearsWhenCleared() throws {
        let input = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(input))
        input.tap()
        input.typeText("Hello")

        let send = app.buttons["chat_send_button"]
        XCTAssertTrue(waitForElement(send, timeout: 3))

        // Clear the text
        let textValue = input.value as? String ?? ""
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: textValue.count)
        input.typeText(deleteString)

        // Mic should reappear
        let mic = app.buttons["chat_mic_button"]
        XCTAssertTrue(waitForElement(mic, timeout: 3), "Mic button should reappear when text is cleared")
    }

    func testAttachButtonExists() throws {
        let attach = app.buttons["chat_attach_button"]
        XCTAssertTrue(waitForElement(attach), "Attachment button should exist")
    }

    func testTypingAndSendingMessage() throws {
        let input = app.textFields["chat_input_field"]
        XCTAssertTrue(waitForElement(input))
        input.tap()
        input.typeText("Test message from UI test")

        let send = app.buttons["chat_send_button"]
        XCTAssertTrue(waitForElement(send, timeout: 3))
        send.tap()

        // After sending, input should be cleared
        // Give it a moment for the UI to update
        sleep(1)
        let inputValue = input.value as? String ?? ""
        XCTAssertTrue(inputValue.isEmpty || inputValue == "Message...", "Input should be cleared after sending")

        // The sent message should appear in the messages area
        let sentMessage = app.staticTexts["Test message from UI test"]
        XCTAssertTrue(waitForElement(sentMessage, timeout: 5), "Sent message should appear in chat")
    }
}
