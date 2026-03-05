import Foundation

// MARK: - LearningTracker Data Provider

enum LearningTrackerDataProvider: ToolkitDataProvider {
    static let toolkitId = "learningTracker"
    static let displayName = "Learning Tracker"
    static let relevanceKeywords: [String] = ["learning", "course", "skill", "study", "progress", "education", "practice", "training", "tutorial", "mastery"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_learningTracker_cache"),
              let entries = try? JSONDecoder().decode([LearningTrackerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/learningTracker/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/learningTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
