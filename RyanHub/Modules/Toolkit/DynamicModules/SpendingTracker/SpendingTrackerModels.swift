import Foundation

// MARK: - SpendingTracker Enums

enum SpendingCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case groceries
    case transport
    case shopping
    case entertainment
    case health
    case housing
    case utilities
    case subscriptions
    case education
    case personalCare
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food & Dining"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .health: return "Health & Fitness"
        case .housing: return "Housing & Rent"
        case .utilities: return "Utilities & Bills"
        case .subscriptions: return "Subscriptions"
        case .education: return "Education"
        case .personalCare: return "Personal Care"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .groceries: return "cart.fill"
        case .transport: return "car.fill"
        case .shopping: return "bag.fill"
        case .entertainment: return "tv.fill"
        case .health: return "heart.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .education: return "book.fill"
        case .personalCare: return "sparkles"
        case .other: return "ellipsis.circle.fill"
        }
    }

    /// Accent color name for chart segments (maps to design system palette)
    var colorName: String {
        switch self {
        case .food: return "hubAccentYellow"
        case .groceries: return "hubAccentGreen"
        case .transport: return "hubPrimary"
        case .shopping: return "hubAccentRed"
        case .entertainment: return "hubPrimaryLight"
        case .health: return "hubAccentGreen"
        case .housing: return "hubAccentYellow"
        case .utilities: return "hubAccentYellow"
        case .subscriptions: return "hubPrimaryLight"
        case .education: return "hubPrimary"
        case .personalCare: return "hubPrimaryLight"
        case .other: return "hubAccentRed"
        }
    }
}

enum PaymentMethod: String, Codable, CaseIterable, Identifiable {
    case cash
    case creditCard
    case debitCard
    case mobilePay
    case bankTransfer
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .mobilePay: return "Mobile Pay"
        case .bankTransfer: return "Bank Transfer"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .mobilePay: return "iphone"
        case .bankTransfer: return "building.columns.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - SpendingTrackerEntry

struct SpendingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amount: Double
    var category: SpendingCategory
    var paymentMethod: PaymentMethod
    var isRecurring: Bool
    var note: String

    // MARK: Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return "" }
        let out = DateFormatter()
        out.dateStyle = .none
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dayString: String {
        String(date.prefix(10)) // "yyyy-MM-dd"
    }

    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }

    var summaryLine: String {
        var parts: [String] = [formattedAmount, category.displayName]
        if !note.isEmpty { parts.append(note) }
        parts.append(paymentMethod.displayName)
        if isRecurring { parts.append("Recurring") }
        return parts.joined(separator: " · ")
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }
}

// MARK: - SpendingTrackerEntry Helpers

extension SpendingTrackerEntry {
    static func makeDateString(from date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }
}