import Foundation

/// Represents a single chat session, analogous to a conversation thread.
/// Sessions are listed in the sidebar and each contains its own message history.
struct ChatSession: Identifiable, Codable, Equatable {
    let id: String
    var title: String
    var createdAt: Date
    var lastMessageAt: Date
    var messageCount: Int
    var lastMessagePreview: String

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        createdAt: Date = .now,
        lastMessageAt: Date = .now,
        messageCount: Int = 0,
        lastMessagePreview: String = ""
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastMessageAt = lastMessageAt
        self.messageCount = messageCount
        self.lastMessagePreview = lastMessagePreview
    }
}

// MARK: - Persistence

extension ChatSession {
    private static let storageKey = "ryanhub_chat_sessions"
    private static let maxSessions = 50

    /// Save sessions to UserDefaults.
    static func saveSessions(_ sessions: [ChatSession]) {
        let trimmed = Array(sessions.prefix(maxSessions))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Load sessions from UserDefaults, sorted by lastMessageAt descending.
    static func loadSessions() -> [ChatSession] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let sessions = try? JSONDecoder().decode([ChatSession].self, from: data) else {
            return []
        }
        return sessions.sorted { $0.lastMessageAt > $1.lastMessageAt }
    }

    /// Delete a specific session and its messages.
    static func deleteSession(id: String) {
        var sessions = loadSessions()
        sessions.removeAll { $0.id == id }
        saveSessions(sessions)
        // Remove the session's messages
        let messagesKey = ChatMessage.storageKey(for: id)
        UserDefaults.standard.removeObject(forKey: messagesKey)
    }
}

// MARK: - Date Grouping

extension ChatSession {
    /// Group label for sidebar display (Today, Yesterday, Previous 7 Days, Earlier).
    var dateGroup: DateGroup {
        let calendar = Calendar.current
        let now = Date.now

        if calendar.isDateInToday(lastMessageAt) {
            return .today
        } else if calendar.isDateInYesterday(lastMessageAt) {
            return .yesterday
        } else if let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  lastMessageAt > sevenDaysAgo {
            return .previousWeek
        } else {
            return .earlier
        }
    }

    enum DateGroup: String, CaseIterable, Comparable {
        case today = "Today"
        case yesterday = "Yesterday"
        case previousWeek = "Previous 7 Days"
        case earlier = "Earlier"

        private var sortOrder: Int {
            switch self {
            case .today: return 0
            case .yesterday: return 1
            case .previousWeek: return 2
            case .earlier: return 3
            }
        }

        static func < (lhs: DateGroup, rhs: DateGroup) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}
