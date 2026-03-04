import Foundation

// MARK: - SleepLog Models

struct SleepLogEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var sleepHours: Double
    var qualityRating: Int
    var wakeUpMood: String
    var bedtime: String
    var wakeTime: String
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(sleepHours)")
            parts.append("\(qualityRating)")
            parts.append(wakeUpMood)
            parts.append(bedtime)
            parts.append(wakeTime)
        return parts.joined(separator: " | ")
    }
}
