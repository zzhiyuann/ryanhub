import Foundation

// MARK: - ScreenTimeTracker Data Provider

enum ScreenTimeTrackerDataProvider: ToolkitDataProvider {
    static let toolkitId = "screenTimeTracker"
    static let displayName = "Screen Time Tracker"
    static let relevanceKeywords: [String] = ["screen time", "digital wellness", "phone usage", "screen goal", "device", "apps", "mindful", "digital detox", "hours", "productivity"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_screenTimeTracker_cache"),
              let entries = try? JSONDecoder().decode([ScreenTimeTrackerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/screenTimeTracker/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/screenTimeTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
