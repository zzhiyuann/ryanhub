import Foundation

// MARK: - CoffeeTracker Data Provider

/// Provides coffee tracker data for chat context injection.
/// Reads from bridge server at /modules/coffeeTracker/data.
enum CoffeeTrackerDataProvider: ToolkitDataProvider {

    static let toolkitId = "coffeeTracker"
    static let displayName = "Coffee Tracker"

    static let relevanceKeywords: [String] = [
        "coffee", "caffeine", "espresso", "latte", "cappuccino", "咖啡", "咖啡因", "饮料", "drink", "energy"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_coffeeTracker_cache"),
              let entries = try? JSONDecoder().decode([CoffeeTrackerEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/coffeeTracker/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/coffeeTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
