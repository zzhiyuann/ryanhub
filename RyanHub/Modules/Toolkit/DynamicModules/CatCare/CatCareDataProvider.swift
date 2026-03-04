import Foundation

// MARK: - CatCare Data Provider

/// Provides cat care data for chat context injection.
/// Reads from bridge server at /modules/catCare/data.
enum CatCareDataProvider: ToolkitDataProvider {

    static let toolkitId = "catCare"
    static let displayName = "Cat Care"

    static let relevanceKeywords: [String] = [
        "cat", "feeding", "vet", "pet", "feline", "猫", "喂食", "兽医", "宠物", "就诊"
    ]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        // Read data synchronously from cached UserDefaults
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_catCare_cache"),
              let entries = try? JSONDecoder().decode([CatCareEntry].self, from: data),
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
        lines.append("  - Add entry: curl -X POST http://localhost:18790/modules/catCare/data/add -H 'Content-Type: application/json' -d '<json>'")
        lines.append("  - View all: curl http://localhost:18790/modules/catCare/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
