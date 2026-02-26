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
    /// ID of the message being replied to (quote-reply feature).
    var replyToId: String?
    /// Short preview of the quoted message for display.
    var replyToPreview: String?

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
        hasImageOnDisk: Bool = false,
        replyToId: String? = nil,
        replyToPreview: String? = nil
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
        self.replyToId = replyToId
        self.replyToPreview = replyToPreview
    }

    // Custom decoder for backward compatibility with older stored messages
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
        replyToId = try container.decodeIfPresent(String.self, forKey: .replyToId)
        replyToPreview = try container.decodeIfPresent(String.self, forKey: .replyToPreview)
    }

    private enum CodingKeys: String, CodingKey {
        case id, content, role, timestamp, isStreaming
        case imageBase64, voiceBase64, voiceDuration, hasImageOnDisk
        case replyToId, replyToPreview
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
    /// Single fixed key for all chat messages (single-chat flow).
    private static let storageKey = "ryanhub_chat_messages_v2"
    private static let maxStoredMessages = 200

    /// Legacy keys for migration from multi-session system.
    private static let legacyStorageKey = "ryanhub_chat_messages"
    private static let legacySessionsKey = "ryanhub_chat_sessions"

    /// Save messages to UserDefaults under the single fixed key.
    /// Image data is written to disk files and stripped from UserDefaults.
    static func save(_ messages: [ChatMessage]) {
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
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Load messages from UserDefaults.
    /// Messages with hasImageOnDisk=true will have their image data restored from disk.
    static func loadSaved() -> [ChatMessage] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
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

    /// Clear all saved messages.
    static func clearSaved() {
        // Delete associated image files before clearing messages
        let messages = loadSaved()
        for msg in messages where msg.hasImageOnDisk {
            deleteImageFromDisk(messageId: msg.id)
        }
        UserDefaults.standard.removeObject(forKey: storageKey)
    }

    /// Migrate messages from the old multi-session system into the new single-chat key.
    /// Merges all session messages into one flat list, sorted by timestamp.
    /// Called once; old keys are cleaned up after migration.
    static func migrateFromMultiSession() {
        // Already migrated if we have data under the new key
        guard UserDefaults.standard.data(forKey: storageKey) == nil else { return }

        var allMessages: [ChatMessage] = []

        // 1. Check for legacy pre-session messages
        if let data = UserDefaults.standard.data(forKey: legacyStorageKey),
           let msgs = try? JSONDecoder().decode([ChatMessage].self, from: data) {
            allMessages.append(contentsOf: msgs)
            UserDefaults.standard.removeObject(forKey: legacyStorageKey)
        }

        // 2. Check for session-based messages
        if let sessionsData = UserDefaults.standard.data(forKey: legacySessionsKey),
           let sessions = try? JSONDecoder().decode([LegacySession].self, from: sessionsData) {
            for session in sessions {
                let sessionKey = "ryanhub_chat_messages_\(session.id)"
                if let msgData = UserDefaults.standard.data(forKey: sessionKey),
                   let msgs = try? JSONDecoder().decode([ChatMessage].self, from: msgData) {
                    allMessages.append(contentsOf: msgs)
                }
                // Clean up old session message key
                UserDefaults.standard.removeObject(forKey: sessionKey)
            }
            // Clean up sessions list key
            UserDefaults.standard.removeObject(forKey: legacySessionsKey)
        }

        guard !allMessages.isEmpty else { return }

        // Sort by timestamp and save under the new single key
        allMessages.sort { $0.timestamp < $1.timestamp }
        // De-duplicate by ID
        var seenIds = Set<String>()
        allMessages = allMessages.filter { seenIds.insert($0.id).inserted }
        save(allMessages)
    }

    /// Minimal struct for decoding legacy session data during migration.
    private struct LegacySession: Codable {
        let id: String
    }
}
