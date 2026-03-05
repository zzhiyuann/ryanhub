import Foundation

// MARK: - PlantCareTracker Data Provider

enum PlantCareTrackerDataProvider: ToolkitDataProvider {
    static let toolkitId = "plantCareTracker"
    static let displayName = "Plant Care Tracker"
    static let relevanceKeywords: [String] = ["plant", "water", "watering", "houseplant", "garden", "fertilize", "green", "care", "botanical", "succulent"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_plantCareTracker_cache"),
              let entries = try? JSONDecoder().decode([PlantCareTrackerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/plantCareTracker/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/plantCareTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
