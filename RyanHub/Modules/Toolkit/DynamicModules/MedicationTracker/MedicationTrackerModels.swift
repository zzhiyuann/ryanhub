import Foundation

// MARK: - MedicationTracker Models

struct MedicationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var medicationName: String
    var dosage: String
    var frequency: String
    var scheduledTime: String
    var taken: Bool
    var refillDate: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(medicationName)
            parts.append(dosage)
            parts.append(frequency)
            parts.append(scheduledTime)
            parts.append("\(taken)")
            if let v = refillDate { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
