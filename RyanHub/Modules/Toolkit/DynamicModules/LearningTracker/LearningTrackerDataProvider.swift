import Foundation

// MARK: - LearningTracker Data Provider

/// Provides learning tracker data for chat context injection.
/// Reads from bridge server at /modules/learningTracker/data.
enum LearningTrackerDataProvider: ToolkitDataProvider {

    static let toolkitId = "learningTracker"
    static let displayName = "Learning Tracker"

    static let relevanceKeywords: [String] = [
        "course", "skill", "learning", "study", "progress", "training", "education", "lesson", "practice", "课程", "学习", "技能", "进度", "练习"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_learningTracker_cache"),
              let entries = try? JSONDecoder().decode([LearningTrackerEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/learningTracker/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/learningTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
