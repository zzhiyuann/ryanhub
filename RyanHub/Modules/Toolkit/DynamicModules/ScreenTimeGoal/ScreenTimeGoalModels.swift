import Foundation

// MARK: - ScreenTimeGoal Models

struct ScreenTimeGoalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var goalHours: Double
    var actualHours: Double
    var goalMet: Bool
    var category: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(goalHours)")
            parts.append("\(actualHours)")
            parts.append("\(goalMet)")
            if let v = category { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
