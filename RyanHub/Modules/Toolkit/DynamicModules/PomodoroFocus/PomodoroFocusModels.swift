import Foundation

// MARK: - PomodoroFocus Models

struct PomodoroFocusEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var taskName: String
    var duration: Int
    var completed: Bool
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(taskName)
            parts.append("\(duration)")
            parts.append("\(completed)")
        return parts.joined(separator: " | ")
    }
}
