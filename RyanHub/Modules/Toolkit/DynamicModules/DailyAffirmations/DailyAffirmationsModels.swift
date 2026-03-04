import Foundation

// MARK: - DailyAffirmations Models

struct DailyAffirmationsEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var text: String
    var category: String
    var isFavorite: Bool
    var displayDate: String
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(text)
            parts.append(category)
            parts.append("\(isFavorite)")
            parts.append(displayDate)
        return parts.joined(separator: " | ")
    }
}
