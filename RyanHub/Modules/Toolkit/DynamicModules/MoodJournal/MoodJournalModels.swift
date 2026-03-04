import Foundation

// MARK: - MoodJournal Models

struct MoodJournalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var rating: Int
    var mood: String
    var energy: Int
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(rating)")
            parts.append(mood)
            parts.append("\(energy)")
        return parts.joined(separator: " | ")
    }
}
