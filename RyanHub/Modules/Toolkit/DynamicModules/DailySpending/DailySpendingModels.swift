import Foundation

// MARK: - DailySpending Models

struct DailySpendingEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amount: Double
    var category: String
    var description: String
    var paymentMethod: String?
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(amount)")
            parts.append(category)
            parts.append(description)
            if let v = paymentMethod { parts.append("\(v)") }
        return parts.joined(separator: " | ")
    }
}
