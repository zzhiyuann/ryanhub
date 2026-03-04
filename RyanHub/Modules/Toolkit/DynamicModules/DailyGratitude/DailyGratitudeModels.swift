import Foundation

// MARK: - DailyGratitude Models

struct DailyGratitudeEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var entry1: String
    var entry2: String
    var entry3: String
    var mood: Int
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(entry1)
            parts.append(entry2)
            parts.append(entry3)
            parts.append("\(mood)")
        return parts.joined(separator: " | ")
    }
}
