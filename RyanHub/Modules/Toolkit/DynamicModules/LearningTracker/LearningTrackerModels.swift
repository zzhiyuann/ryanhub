import Foundation

// MARK: - LearningTracker Models

struct LearningTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var courseName: String
    var category: String
    var totalUnits: Int
    var completedUnits: Int
    var progressPercent: Double
    var hoursSpent: Double
    var targetHours: Double?
    var isCompleted: Bool
    var lastStudiedDate: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(courseName)
            parts.append(category)
            parts.append("\(totalUnits)")
            parts.append("\(completedUnits)")
            parts.append("\(progressPercent)")
            parts.append("\(hoursSpent)")
            if let v = targetHours { parts.append("\(v)") }
            parts.append("\(isCompleted)")
            if let v = lastStudiedDate { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
