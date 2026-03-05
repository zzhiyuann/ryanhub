import Foundation

// MARK: - SubscriptionTracker Models

enum BillingCycle: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case semiAnnually
    case annually
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .quarterly: return "Quarterly"
        case .semiAnnually: return "Semi-Annually"
        case .annually: return "Annually"
        }
    }
    var icon: String {
        switch self {
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar"
        case .quarterly: return "calendar.badge.plus"
        case .semiAnnually: return "calendar.circle"
        case .annually: return "calendar.circle.fill"
        }
    }
}

enum SubscriptionCategory: String, Codable, CaseIterable, Identifiable {
    case streaming
    case music
    case productivity
    case cloudStorage
    case healthFitness
    case foodDelivery
    case newsMedia
    case education
    case gaming
    case utilities
    case finance
    case social
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .streaming: return "Streaming"
        case .music: return "Music"
        case .productivity: return "Productivity"
        case .cloudStorage: return "Cloud Storage"
        case .healthFitness: return "Health & Fitness"
        case .foodDelivery: return "Food & Delivery"
        case .newsMedia: return "News & Media"
        case .education: return "Education"
        case .gaming: return "Gaming"
        case .utilities: return "Utilities"
        case .finance: return "Finance"
        case .social: return "Social"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .streaming: return "play.tv.fill"
        case .music: return "music.note"
        case .productivity: return "hammer.fill"
        case .cloudStorage: return "cloud.fill"
        case .healthFitness: return "heart.fill"
        case .foodDelivery: return "fork.knife"
        case .newsMedia: return "newspaper.fill"
        case .education: return "graduationcap.fill"
        case .gaming: return "gamecontroller.fill"
        case .utilities: return "wrench.and.screwdriver.fill"
        case .finance: return "banknote.fill"
        case .social: return "person.2.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case creditCard
    case debitCard
    case applePay
    case paypal
    case bankTransfer
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .applePay: return "Apple Pay"
        case .paypal: return "PayPal"
        case .bankTransfer: return "Bank Transfer"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .applePay: return "apple.logo"
        case .paypal: return "p.circle.fill"
        case .bankTransfer: return "building.columns.fill"
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
    var name: String
    var amount: Double
    var billingCycle: BillingCycle
    var category: SubscriptionCategory
    var nextRenewalDate: Date
    var isActive: Bool
    var paymentMethod: PaymentMethod
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(name)")
        parts.append("\(amount)")
        parts.append("\(billingCycle)")
        parts.append("\(category)")
        parts.append("\(nextRenewalDate)")
        parts.append("\(isActive)")
        parts.append("\(paymentMethod)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
