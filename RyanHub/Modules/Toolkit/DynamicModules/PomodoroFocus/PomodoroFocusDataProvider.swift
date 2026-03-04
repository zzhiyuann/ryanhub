import Foundation

// MARK: - PomodoroFocus Data Provider

/// Provides pomodoro focus data for chat context injection.
/// Reads from bridge server at /modules/pomodoroFocus/data.
enum PomodoroFocusDataProvider: ToolkitDataProvider {

    static let toolkitId = "pomodoroFocus"
    static let displayName = "Pomodoro Focus"

    static let relevanceKeywords: [String] = [
        "pomodoro", "focus", "timer", "productivity", "session", "task", "work", "番茄钟", "专注", "任务"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_pomodoroFocus_cache"),
              let entries = try? JSONDecoder().decode([PomodoroFocusEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/pomodoroFocus/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/pomodoroFocus/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
