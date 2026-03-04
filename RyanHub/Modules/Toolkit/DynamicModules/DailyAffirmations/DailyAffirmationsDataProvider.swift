import Foundation

// MARK: - DailyAffirmations Data Provider

/// Provides daily affirmations data for chat context injection.
/// Reads from bridge server at /modules/dailyAffirmations/data.
enum DailyAffirmationsDataProvider: ToolkitDataProvider {

    static let toolkitId = "dailyAffirmations"
    static let displayName = "Daily Affirmations"

    static let relevanceKeywords: [String] = [
        "affirmation", "motivation", "positivity", "mindset", "daily", "self-talk", "encouragement", "每日", "励志", "正念"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_dailyAffirmations_cache"),
              let entries = try? JSONDecoder().decode([DailyAffirmationsEntry].self, from: data),
              !entries.isEmpty else {
            return nil
        }

        var lines: [String] = ["[\(displayName)]"]
        lines.append("Total entries: \(entries.count)")

        // Show last 5 entries
        let recent = entries.suffix(5)
        for entry in recent {
            lines.append("  - \(entry.summaryLine)")
        }

        // Action hints for the AI agent
        lines.append("Actions:")
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/dailyAffirmations/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/dailyAffirmations/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
