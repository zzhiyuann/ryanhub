import Foundation

// MARK: - GroceryList Data Provider

enum GroceryListDataProvider: ToolkitDataProvider {
    static let toolkitId = "groceryList"
    static let displayName = "Grocery List"
    static let relevanceKeywords: [String] = ["grocery", "shopping", "list", "food", "budget", "store", "cart", "meal", "ingredients", "spending"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_groceryList_cache"),
              let entries = try? JSONDecoder().decode([GroceryListEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/groceryList/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/groceryList/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
