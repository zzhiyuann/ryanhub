import Foundation

// MARK: - MoodJournal Data Provider

enum MoodJournalDataProvider: ToolkitDataProvider {
    static let toolkitId = "moodJournal"
    static let displayName = "Mood Journal"
    static let relevanceKeywords: [String] = ["mood", "journal", "emotion", "feeling", "mental health", "wellbeing", "diary", "happiness", "anxiety", "stress"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_moodJournal_cache"),
              let entries = try? JSONDecoder().decode([MoodJournalEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        var lines: [String] = ["[\(displayName)]"]
        lines.append("Total entries: \(entries.count)")
        let recent = entries.suffix(5)
        for entry in recent {
            lines.append("  - \(entry.summaryLine)")
        }
        lines.append("Actions:")
        lines.append("  - Add: POST http://localhost:18790/modules/moodJournal/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/moodJournal/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
