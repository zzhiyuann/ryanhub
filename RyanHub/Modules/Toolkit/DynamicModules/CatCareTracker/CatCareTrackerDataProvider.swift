import Foundation

// MARK: - CatCareTracker Data Provider

enum CatCareTrackerDataProvider: ToolkitDataProvider {
    static let toolkitId = "catCareTracker"
    static let displayName = "Cat Care Tracker"
    static let relevanceKeywords: [String] = ["cat", "pet", "feeding", "vet", "veterinary", "weight", "medication", "health", "animal", "kitten"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_catCareTracker_cache"),
              let entries = try? JSONDecoder().decode([CatCareTrackerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/catCareTracker/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/catCareTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
