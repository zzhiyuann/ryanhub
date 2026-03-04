import Foundation

// MARK: - PlantWatering Models

struct PlantWateringEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var plantName: String
    var wateringIntervalDays: Int
    var lastWateredDate: String
    var nextWateringDate: String
    var location: String?
    var waterAmountMl: Double?
    var sunlight: String?
    var isOverdue: Bool
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(plantName)
            parts.append("\(wateringIntervalDays)")
            parts.append(lastWateredDate)
            parts.append(nextWateringDate)
            if let v = location { parts.append("\(v)") }
            if let v = waterAmountMl { parts.append("\(v)") }
            if let v = sunlight { parts.append("\(v)") }
            parts.append("\(isOverdue)")
        return parts.joined(separator: " | ")
    }
}
