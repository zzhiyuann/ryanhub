import Foundation

// MARK: - SpendingTracker Models

enum SpendingCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case groceries
    case transport
    case entertainment
    case shopping
    case health
    case bills
    case education
    case coffee
    case subscriptions
    case gifts
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .food: return "Food & Dining"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .health: return "Health & Fitness"
        case .bills: return "Bills & Utilities"
        case .education: return "Education"
        case .coffee: return "Coffee & Drinks"
        case .subscriptions: return "Subscriptions"
        case .gifts: return "Gifts & Donations"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transport: return "car.fill"
        case .entertainment: return "film.fill"
        case .shopping: return "bag.fill"
        case .health: return "heart.fill"
        case .bills: return "doc.text.fill"
        case .education: return "book.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .gifts: return "gift.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum SpendingPaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case creditCard
    case debitCard
    case applePay
    case venmo
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .applePay: return "Apple Pay"
        case .venmo: return "Venmo / Zelle"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .applePay: return "apple.logo"
        case .venmo: return "arrow.left.arrow.right"
        case .other: return "ellipsis.circle"
        }
    }
}

struct SpendingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amount: Double
    var category: SpendingCategory
    var paymentMethod: SpendingPaymentMethod
    var merchant: String
    var isRecurring: Bool
    var note: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(amount)")
        parts.append("\(category)")
        parts.append("\(paymentMethod)")
        parts.append("\(merchant)")
        parts.append("\(isRecurring)")
        return parts.joined(separator: " | ")
    }
}
