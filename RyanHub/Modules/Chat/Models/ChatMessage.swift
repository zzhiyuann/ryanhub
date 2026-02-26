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
    /// True when the image was saved to disk (survives persistence even after
    /// imageBase64 is stripped from UserDefaults).
    var hasImageOnDisk: Bool

    enum Role: String, Codable {
        case user
        case assistant
    }

    /// The type of content this message carries.
    var messageType: MessageType {
        if imageBase64 != nil || hasImageOnDisk { return .image }
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
        voiceDuration: TimeInterval? = nil,
        hasImageOnDisk: Bool = false
    ) {
        self.id = id
        self.content = content
        self.role = role
        self.timestamp = timestamp
        self.isStreaming = isStreaming
        self.imageBase64 = imageBase64
        self.voiceBase64 = voiceBase64
        self.voiceDuration = voiceDuration
        self.hasImageOnDisk = hasImageOnDisk
    }

    // Custom decoder so old messages without hasImageOnDisk decode as false
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        role = try container.decode(Role.self, forKey: .role)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isStreaming = try container.decode(Bool.self, forKey: .isStreaming)
        imageBase64 = try container.decodeIfPresent(String.self, forKey: .imageBase64)
        voiceBase64 = try container.decodeIfPresent(String.self, forKey: .voiceBase64)
        voiceDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .voiceDuration)
        hasImageOnDisk = try container.decodeIfPresent(Bool.self, forKey: .hasImageOnDisk) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, role, timestamp, isStreaming
        case imageBase64, voiceBase64, voiceDuration, hasImageOnDisk
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

// MARK: - Image Disk Storage

extension ChatMessage {
    /// Directory where chat images are persisted to survive tab switches and relaunches.
    private static var imageStorageDirectory: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ChatImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// File URL for a given message's image.
    static func imageFileURL(for messageId: String) -> URL {
        imageStorageDirectory.appendingPathComponent("\(messageId).jpg")
    }

    /// Save image data to disk for a message. Returns true on success.
    @discardableResult
    static func saveImageToDisk(messageId: String, base64: String) -> Bool {
        guard let data = Data(base64Encoded: base64) else { return false }
        let url = imageFileURL(for: messageId)
        do {
            try data.write(to: url)
            return true
        } catch {
            return false
        }
    }

    /// Load image data from disk for a message. Returns nil if not found.
    static func loadImageFromDisk(messageId: String) -> Data? {
        let url = imageFileURL(for: messageId)
        return try? Data(contentsOf: url)
    }

    /// Delete image file from disk for a message.
    static func deleteImageFromDisk(messageId: String) {
        let url = imageFileURL(for: messageId)
        try? FileManager.default.removeItem(at: url)
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
    /// Image data is written to disk files and stripped from UserDefaults.
    static func save(_ messages: [ChatMessage], sessionId: String? = nil) {
        let key = sessionId.map { storageKey(for: $0) } ?? legacyStorageKey
        let trimmed = Array(messages.suffix(maxStoredMessages)).map { msg -> ChatMessage in
            var stripped = msg
            if let base64 = stripped.imageBase64 {
                // Write image to disk, then strip base64 from UserDefaults payload
                saveImageToDisk(messageId: msg.id, base64: base64)
                stripped = ChatMessage(
                    id: msg.id,
                    content: msg.content.isEmpty ? "[Image]" : msg.content,
                    role: msg.role,
                    timestamp: msg.timestamp,
                    isStreaming: false,
                    hasImageOnDisk: true
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
    /// Messages with hasImageOnDisk=true will have their image data restored from disk.
    static func loadSaved(sessionId: String? = nil) -> [ChatMessage] {
        let key = sessionId.map { storageKey(for: $0) } ?? legacyStorageKey
        guard let data = UserDefaults.standard.data(forKey: key),
              let messages = try? JSONDecoder().decode([ChatMessage].self, from: data) else {
            return []
        }
        // Fix legacy data: ensure every message has a unique ID.
        var seenIds = Set<String>()
        let deduped = messages.sorted { $0.timestamp < $1.timestamp }.map { msg -> ChatMessage in
            var resolved = msg
            if seenIds.contains(msg.id) {
                let newId = "resp-\(msg.id)"
                resolved = ChatMessage(
                    id: seenIds.contains(newId) ? UUID().uuidString : newId,
                    content: msg.content,
                    role: msg.role,
                    timestamp: msg.timestamp,
                    isStreaming: msg.isStreaming,
                    imageBase64: msg.imageBase64,
                    voiceBase64: msg.voiceBase64,
                    voiceDuration: msg.voiceDuration,
                    hasImageOnDisk: msg.hasImageOnDisk
                )
            } else {
                seenIds.insert(msg.id)
            }

            // Restore image data from disk if available
            if resolved.hasImageOnDisk && resolved.imageBase64 == nil,
               let imageData = loadImageFromDisk(messageId: resolved.id) {
                resolved.imageBase64 = imageData.base64EncodedString()
            }
            return resolved
        }
        return deduped
    }

    /// Clear saved messages for a specific session (or legacy key).
    static func clearSaved(sessionId: String? = nil) {
        // Delete associated image files before clearing messages
        let messages = loadSaved(sessionId: sessionId)
        for msg in messages where msg.hasImageOnDisk {
            deleteImageFromDisk(messageId: msg.id)
        }
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
