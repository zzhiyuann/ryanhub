import Foundation

// MARK: - CommuteLog Models

struct CommuteLogEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var departureTime: String
    var arrivalTime: String
    var durationMinutes: Double
    var origin: String
    var destination: String
    var transportMode: String
    var distanceKm: Double?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(departureTime)
            parts.append(arrivalTime)
            parts.append("\(durationMinutes)")
            parts.append(origin)
            parts.append(destination)
            parts.append(transportMode)
            if let v = distanceKm { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
