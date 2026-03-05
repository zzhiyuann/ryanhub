import Foundation

// MARK: - PeopleNotes Data Provider

enum PeopleNotesDataProvider: ToolkitDataProvider {
    static let toolkitId = "peopleNotes"
    static let displayName = "People Notes"
    static let relevanceKeywords: [String] = ["people", "contacts", "networking", "meetings", "relationships", "notes", "crm", "follow-up", "connections", "remember"]

    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    static func buildContextSummary() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_peopleNotes_cache"),
              let entries = try? JSONDecoder().decode([PeopleNotesEntry].self, from: data),
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
        lines.append("  - Add: POST http://localhost:18790/modules/peopleNotes/data/add")
        lines.append("  - View: GET http://localhost:18790/modules/peopleNotes/data")
        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
