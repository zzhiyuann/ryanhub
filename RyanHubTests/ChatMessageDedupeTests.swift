import XCTest
@testable import RyanHub

final class ChatMessageDedupeTests: XCTestCase {

    private let testStorageKey = "ryanhub_chat_messages_v2"

    override func tearDown() {
        super.tearDown()
        UserDefaults.standard.removeObject(forKey: testStorageKey)
    }

    // MARK: - Bug 2 Regression: Dedupe must track renamed IDs

    /// When loadSaved() encounters duplicate IDs, renamed IDs must be added to
    /// seenIds so they don't collide with real response messages.
    func testLoadSavedDedupeTracksRenamedIds() {
        // Arrange: Two messages with the same ID "ABC" followed by a real response "resp-ABC".
        // Before the fix, the second "ABC" would be renamed to "resp-ABC" but that ID
        // was never tracked, so the real "resp-ABC" would pass as unique — producing
        // two messages with id "resp-ABC" (ForEach crash / rendering glitch).
        let now = Date()
        let messages: [ChatMessage] = [
            ChatMessage(id: "ABC", content: "User msg", role: .user, timestamp: now),
            ChatMessage(id: "ABC", content: "Duplicate user msg", role: .user,
                        timestamp: now.addingTimeInterval(1)),
            ChatMessage(id: "resp-ABC", content: "Response", role: .assistant,
                        timestamp: now.addingTimeInterval(2)),
        ]

        // Persist to UserDefaults
        let data = try! JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: testStorageKey)

        // Act
        let loaded = ChatMessage.loadSaved()

        // Assert: All IDs must be unique
        let ids = loaded.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
                       "Duplicate IDs found after dedupe: \(ids)")
        // The three messages should all be present
        XCTAssertEqual(loaded.count, 3)
    }

    /// Verify that normal (non-duplicate) messages pass through loadSaved unchanged.
    func testLoadSavedPreservesUniqueMessages() {
        let now = Date()
        let messages: [ChatMessage] = [
            ChatMessage(id: "msg-1", content: "Hello", role: .user, timestamp: now),
            ChatMessage(id: "resp-msg-1", content: "Hi!", role: .assistant,
                        timestamp: now.addingTimeInterval(1)),
            ChatMessage(id: "msg-2", content: "How are you?", role: .user,
                        timestamp: now.addingTimeInterval(2)),
        ]

        let data = try! JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: testStorageKey)

        let loaded = ChatMessage.loadSaved()
        XCTAssertEqual(loaded.count, 3)
        XCTAssertEqual(loaded[0].id, "msg-1")
        XCTAssertEqual(loaded[1].id, "resp-msg-1")
        XCTAssertEqual(loaded[2].id, "msg-2")
    }

    /// Edge case: three messages with the same ID should all get unique IDs.
    func testLoadSavedDedupeTripleDuplicate() {
        let now = Date()
        let messages: [ChatMessage] = [
            ChatMessage(id: "DUP", content: "First", role: .user, timestamp: now),
            ChatMessage(id: "DUP", content: "Second", role: .user,
                        timestamp: now.addingTimeInterval(1)),
            ChatMessage(id: "DUP", content: "Third", role: .user,
                        timestamp: now.addingTimeInterval(2)),
        ]

        let data = try! JSONEncoder().encode(messages)
        UserDefaults.standard.set(data, forKey: testStorageKey)

        let loaded = ChatMessage.loadSaved()
        let ids = loaded.map { $0.id }
        let uniqueIds = Set(ids)
        XCTAssertEqual(ids.count, uniqueIds.count,
                       "Triple duplicate produced colliding IDs: \(ids)")
        XCTAssertEqual(loaded.count, 3)
    }
}
