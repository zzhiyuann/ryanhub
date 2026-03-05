import Foundation

// MARK: - FocusTimer Data Provider

enum FocusTimerDataProvider: ToolkitDataProvider {
    static let toolkitId = "focusTimer"
    static let displayName = "Focus Timer"
    static let relevanceKeywords: [String] = ["pomodoro", "focus", "timer", "productivity", "deep work", "session", "concentration", "task", "distraction", "time management"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_focusTimer_cache"),
              let entries = try? JSONDecoder().decode([FocusTimerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/focusTimer/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/focusTimer/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
