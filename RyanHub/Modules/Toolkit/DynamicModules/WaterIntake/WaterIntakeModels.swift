import Foundation

// MARK: - WaterIntake Models

struct WaterIntakeEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var glassesConsumed: Int
    var dailyGoal: Int
    var glassSizeML: Double
    var totalML: Double
    var goalReached: Bool
    var lastDrinkTime: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(glassesConsumed)")
            parts.append("\(dailyGoal)")
            parts.append("\(glassSizeML)")
            parts.append("\(totalML)")
            parts.append("\(goalReached)")
            if let v = lastDrinkTime { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
