import Foundation

// MARK: - SubscriptionTracker Models

struct SubscriptionTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var serviceName: String
    var monthlyCost: Double
    var billingCycle: String
    var nextBillingDate: String
    var category: String
    var isActive: Bool
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(serviceName)
            parts.append("\(monthlyCost)")
            parts.append(billingCycle)
            parts.append(nextBillingDate)
            parts.append(category)
            parts.append("\(isActive)")
        return parts.joined(separator: " | ")
    }
}
