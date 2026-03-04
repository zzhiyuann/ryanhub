import Foundation

// MARK: - BookTracker Models

struct BookTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var title: String
    var author: String
    var totalPages: Int
    var currentPage: Int
    var progressPercent: Double
    var startDate: String
    var isFinished: Bool
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(title)
            parts.append(author)
            parts.append("\(totalPages)")
            parts.append("\(currentPage)")
            parts.append("\(progressPercent)")
            parts.append(startDate)
            parts.append("\(isFinished)")
        return parts.joined(separator: " | ")
    }
}
