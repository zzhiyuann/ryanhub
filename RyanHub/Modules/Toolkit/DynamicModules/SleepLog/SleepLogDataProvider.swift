import Foundation

// MARK: - SleepLog Data Provider

/// Provides sleep log data for chat context injection.
/// Reads from bridge server at /modules/sleepLog/data.
enum SleepLogDataProvider: ToolkitDataProvider {

    static let toolkitId = "sleepLog"
    static let displayName = "Sleep Log"

    static let relevanceKeywords: [String] = [
        "sleep", "rest", "hours", "quality", "mood", "wakeup", "insomnia", "fatigue", "睡眠", "起床", "心情", "休息", "睡觉", "疲劳"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_sleepLog_cache"),
              let entries = try? JSONDecoder().decode([SleepLogEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/sleepLog/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/sleepLog/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
