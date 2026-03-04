import Foundation

// MARK: - PeopleNotes Models

struct PeopleNotesEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var personName: String
    var role: String?
    var company: String?
    var meetingContext: String
    var location: String?
    var dateMet: String
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(personName)
            if let v = role { parts.append("\(v)") }
            if let v = company { parts.append("\(v)") }
            parts.append(meetingContext)
            if let v = location { parts.append("\(v)") }
            parts.append(dateMet)
        return parts.joined(separator: " | ")
    }
}
