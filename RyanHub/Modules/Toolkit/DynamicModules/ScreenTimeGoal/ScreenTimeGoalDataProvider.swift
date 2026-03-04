import Foundation

// MARK: - ScreenTimeGoal Data Provider

/// Provides screen time goal data for chat context injection.
/// Reads from bridge server at /modules/screenTimeGoal/data.
enum ScreenTimeGoalDataProvider: ToolkitDataProvider {

    static let toolkitId = "screenTimeGoal"
    static let displayName = "Screen Time Goal"

    static let relevanceKeywords: [String] = [
        "screen time", "phone usage", "digital wellness", "screen limit", "daily goal", "屏幕时间", "手机使用", "数字健康", "用机时长", "时间管理"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_screenTimeGoal_cache"),
              let entries = try? JSONDecoder().decode([ScreenTimeGoalEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/screenTimeGoal/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/screenTimeGoal/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
