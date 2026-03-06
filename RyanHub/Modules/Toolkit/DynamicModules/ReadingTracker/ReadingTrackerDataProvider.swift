import Foundation

// MARK: - ReadingTracker Data Provider

enum ReadingTrackerDataProvider: ToolkitDataProvider {
    static let toolkitId = "readingTracker"
    static let displayName = "Reading Tracker"
    static let relevanceKeywords: [String] = ["reading", "books", "pages", "library", "progress", "novel", "author", "bookmark", "literature", "bookshelf"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_readingTracker_cache"),
              let entries = try? JSONDecoder().decode([ReadingTrackerEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/readingTracker/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/readingTracker/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
