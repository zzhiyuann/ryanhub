import Foundation

// MARK: - CatCare Models

struct CatCareEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var eventType: String
    var timestamp: String
    var foodName: String?
    var portionGrams: Double?
    var vetClinic: String?
    var vetReason: String?
    var nextVisitDue: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(eventType)
            parts.append(timestamp)
            if let v = foodName { parts.append("\(v)") }
            if let v = portionGrams { parts.append("\(v)") }
            if let v = vetClinic { parts.append("\(v)") }
            if let v = vetReason { parts.append("\(v)") }
            if let v = nextVisitDue { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
