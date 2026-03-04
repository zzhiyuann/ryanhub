import Foundation

// MARK: - CoffeeTracker Models

struct CoffeeTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var cupCount: Int
    var drinkType: String
    var caffeinePerCup: Double
    var totalCaffeine: Double
    var loggedAt: String
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(cupCount)")
            parts.append(drinkType)
            parts.append("\(caffeinePerCup)")
            parts.append("\(totalCaffeine)")
            parts.append(loggedAt)
        return parts.joined(separator: " | ")
    }
}
