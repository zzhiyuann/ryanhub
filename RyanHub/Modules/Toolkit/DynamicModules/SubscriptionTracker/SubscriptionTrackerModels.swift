import Foundation

// MARK: - SubscriptionTracker Models

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case semiAnnual
    case yearly
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiAnnual: return "Every 6 Months"
        case .yearly: return "Yearly"
        }
    }
    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.3"
        case .semiAnnual: return "calendar.badge.6"
        case .yearly: return "calendar.badge.12"
        }
    }
}

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case entertainment
    case music
    case productivity
    case cloudStorage
    case fitness
    case news
    case food
    case gaming
    case education
    case utilities
    case finance
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .entertainment: return "Entertainment"
        case .music: return "Music"
        case .productivity: return "Productivity"
        case .cloudStorage: return "Cloud Storage"
        case .fitness: return "Fitness & Health"
        case .news: return "News & Reading"
        case .food: return "Food & Delivery"
        case .gaming: return "Gaming"
        case .education: return "Education"
        case .utilities: return "Utilities & Tools"
        case .finance: return "Finance"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .entertainment: return "tv"
        case .music: return "music.note"
        case .productivity: return "laptopcomputer"
        case .cloudStorage: return "icloud"
        case .fitness: return "figure.run"
        case .news: return "newspaper"
        case .food: return "fork.knife"
        case .gaming: return "gamecontroller"
        case .education: return "graduationcap"
        case .utilities: return "wrench.and.screwdriver"
        case .finance: return "banknote"
        case .other: return "ellipsis.circle"
        }
    }
}

struct SubscriptionTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var serviceName: String
    var amount: Double
    var billingCycle: BillingCycle
    var category: SubscriptionCategory
    var nextRenewalDate: Date
    var usageRating: Int
    var isActive: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(serviceName)")
        parts.append("\(amount)")
        parts.append("\(billingCycle)")
        parts.append("\(category)")
        parts.append("\(nextRenewalDate)")
        parts.append("\(usageRating)")
        parts.append("\(isActive)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
