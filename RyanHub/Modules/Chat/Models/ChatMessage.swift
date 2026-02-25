import Foundation

/// Represents a single message in the chat conversation.
/// Supports text, image, and voice message types.
struct ChatMessage: Identifiable, Codable, Equatable {
    let id: String
    let content: String
    let role: Role
    let timestamp: Date
    var isStreaming: Bool
    var imageBase64: String?
    var voiceBase64: String?
    var voiceDuration: TimeInterval?

    enum Role: String, Codable {
        case user
        case assistant
    }

    /// The type of content this message carries.
    var messageType: MessageType {
        if imageBase64 != nil { return .image }
        if voiceBase64 != nil { return .voice }
        return .text
    }

    enum MessageType {
        case text
        case image
        case voice
    }

    init(
        id: String = UUID().uuidString,
        content: String,
        role: Role,
        timestamp: Date = .now,
        isStreaming: Bool = false,
        imageBase64: String? = nil,
        voiceBase64: String? = nil,
        voiceDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageBase64 = imageBase64
        self.voiceBase64 = voiceBase64
        self.voiceDuration = voiceDuration
    }

    /// Create a user text message.
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(content: content, role: .user)
    }

    /// Create a user message with an image.
    static func userImage(base64: String, caption: String = "") -> ChatMessage {
        ChatMessage(content: caption, role: .user, imageBase64: base64)
    }

    /// Create a user voice message.
    static func userVoice(base64: String, duration: TimeInterval) -> ChatMessage {
        ChatMessage(content: "", role: .user, voiceBase64: base64, voiceDuration: duration)
    }

    /// Create an assistant message (potentially streaming).
    static func assistant(_ content: String, id: String = UUID().uuidString, isStreaming: Bool = false) -> ChatMessage {
        ChatMessage(id: id, content: content, role: .assistant, isStreaming: isStreaming)
    }
}

// MARK: - Persistence

extension ChatMessage {
    private static let legacyStorageKey = "ryanhub_chat_messages"
    private static let maxStoredMessages = 200

    /// Build the UserDefaults key for a given session ID.
    static func storageKey(for sessionId: String) -> String {
        "ryanhub_chat_messages_\(sessionId)"
    }

    /// Save messages to UserDefaults for a specific session.
    static func save(_ messages: [ChatMessage], sessionId: String? = nil) {
        let key = sessionId.map { storageKey(for: $0) } ?? legacyStorageKey
        // Strip image/voice base64 data from saved messages to avoid UserDefaults bloat.
        // Keep the metadata (captions, durations) but clear the large binary payloads.
        let trimmed = Array(messages.suffix(maxStoredMessages)).map { msg -> ChatMessage in
            var stripped = msg
            if stripped.imageBase64 != nil {
                stripped = ChatMessage(
                    id: msg.id,
                    content: msg.content.isEmpty ? "[Image]" : msg.content,
                    role: msg.role,
                    timestamp: msg.timestamp,
                    isStreaming: false,
                    imageBase64: nil
                )
            }
            if stripped.voiceBase64 != nil {
                stripped = ChatMessage(
                    id: msg.id,
                    content: "[Voice message]",
                    role: msg.role,
                    timestamp: msg.timestamp,
                    isStreaming: false,
                    voiceDuration: msg.voiceDuration
                )
            }
            return stripped
        }
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Load messages from UserDefaults for a specific session.
    static func loadSaved(sessionId: String? = nil) -> [ChatMessage] {
        let key = sessionId.map { storageKey(for: $0) } ?? legacyStorageKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        // Fix legacy data: ensure every message has a unique ID.
        // Old code used the same Dispatcher message ID for both user and assistant
        // messages, causing SwiftUI ForEach identity collisions.
        var seenIds = Set<String>()
        let deduped = messages.sorted { $0.timestamp < $1.timestamp }.map { msg -> ChatMessage in
            if seenIds.contains(msg.id) {
                // Duplicate ID — give the later message (typically the assistant reply) a new unique ID.
                let newId = "resp-\(msg.id)"
                return ChatMessage(
                    id: seenIds.contains(newId) ? UUID().uuidString : newId,
                    content: msg.content,
                    role: msg.role,
                    timestamp: msg.timestamp,
                    isStreaming: msg.isStreaming,
                    imageBase64: msg.imageBase64,
                    voiceBase64: msg.voiceBase64,
                    voiceDuration: msg.voiceDuration
                )
            } else {
                seenIds.insert(msg.id)
                return msg
            }
        }
        return deduped
    }

    /// Clear saved messages for a specific session (or legacy key).
    static func clearSaved(sessionId: String? = nil) {
        let key = sessionId.map { storageKey(for: $0) } ?? legacyStorageKey
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// Check if legacy (pre-session) messages exist for migration.
    static var hasLegacyMessages: Bool {
        UserDefaults.standard.data(forKey: legacyStorageKey) != nil
    }

    /// Load and remove legacy messages (used for one-time migration).
    static func migrateLegacyMessages() -> [ChatMessage] {
        let messages = loadSaved(sessionId: nil)
        if !messages.isEmpty {
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }
        return messages
    }
}
