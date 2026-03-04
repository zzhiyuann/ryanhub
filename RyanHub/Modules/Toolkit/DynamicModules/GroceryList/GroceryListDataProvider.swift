import Foundation

// MARK: - GroceryList Data Provider

/// Provides grocery list data for chat context injection.
/// Reads from bridge server at /modules/groceryList/data.
enum GroceryListDataProvider: ToolkitDataProvider {

    static let toolkitId = "groceryList"
    static let displayName = "Grocery List"

    static let relevanceKeywords: [String] = [
        "grocery", "shopping", "list", "food", "supermarket", "买菜", "购物清单", "食品", "超市", "清单"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_groceryList_cache"),
              let entries = try? JSONDecoder().decode([GroceryListEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/groceryList/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/groceryList/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
