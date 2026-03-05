import Foundation

// MARK: - GratitudeJournal Data Provider

enum GratitudeJournalDataProvider: ToolkitDataProvider {
    static let toolkitId = "gratitudeJournal"
    static let displayName = "Gratitude Journal"
    static let relevanceKeywords: [String] = ["gratitude", "journal", "thankful", "grateful", "reflection", "mindfulness", "wellbeing", "positivity", "daily", "happiness"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_gratitudeJournal_cache"),
              let entries = try? JSONDecoder().decode([GratitudeJournalEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/gratitudeJournal/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/gratitudeJournal/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
