import Foundation

/// Represents a single message in the chat conversation.
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let role: Role
    let timestamp: Date
    var isStreaming: Bool

    enum Role: String, Codable {
        case user
        case assistant
    }

    init(
        id: String = UUID().uuidString,
        content: String,
        role: Role,
        timestamp: Date = .now,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.isStreaming = isStreaming
    }

    /// Create a user message.
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(content: content, role: .user)
    }

    /// Create an assistant message (potentially streaming).
    static func assistant(_ content: String, id: String = UUID().uuidString, isStreaming: Bool = false) -> ChatMessage {
        ChatMessage(id: id, content: content, role: .assistant, isStreaming: isStreaming)
    }
}

// MARK: - Persistence

extension ChatMessage {
    private static let storageKey = "cortex_chat_messages"
    private static let maxStoredMessages = 200

    /// Save messages to UserDefaults.
    static func save(_ messages: [ChatMessage]) {
        let trimmed = Array(messages.suffix(maxStoredMessages))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Load messages from UserDefaults.
    static func loadSaved() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        return messages
    }

    /// Clear all saved messages.
    static func clearSaved() {
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
