import Foundation

// MARK: - HabitTracker Models

struct HabitTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var habitName: String
    var isCompleted: Bool
    var currentStreak: Int
    var longestStreak: Int
    var targetDurationMinutes: Double?
    var completedAt: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(habitName)
            parts.append("\(isCompleted)")
            parts.append("\(currentStreak)")
            parts.append("\(longestStreak)")
            if let v = targetDurationMinutes { parts.append("\(v)") }
            if let v = completedAt { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
