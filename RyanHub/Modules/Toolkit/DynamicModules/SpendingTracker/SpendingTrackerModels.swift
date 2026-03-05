import Foundation

// MARK: - Entry

struct SpendingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amount: Double = 0.0
    var category: SpendingCategory = .other
    var paymentMethod: PaymentMethod = .cash
    var isRecurring: Bool = false
    var note: String = ""

    // MARK: Computed

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    var dateOnly: String {
        String(date.prefix(10))
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: parsedDate)
    }

    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }

    var summaryLine: String {
        var parts = ["\(category.displayName)", formattedAmount]
        if isRecurring { parts.append("Recurring") }
        if !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    var shortSummary: String {
        note.isEmpty ? category.displayName : note
    }

    var isToday: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return dateOnly == f.string(from: Date())
    }
}

// MARK: - SpendingCategory

enum SpendingCategory: String, CaseIterable, Codable, Identifiable {
    case groceries
    case dining
    case coffee
    case transport
    case shopping
    case entertainment
    case health
    case bills
    case education
    case personal
    case gifts
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groceries:    return "Groceries"
        case .dining:       return "Dining Out"
        case .coffee:       return "Coffee & Drinks"
        case .transport:    return "Transport"
        case .shopping:     return "Shopping"
        case .entertainment: return "Entertainment"
        case .health:       return "Health & Fitness"
        case .bills:        return "Bills & Utilities"
        case .education:    return "Education"
        case .personal:     return "Personal Care"
        case .gifts:        return "Gifts & Donations"
        case .other:        return "Other"
        }
    }

    var icon: String {
        switch self {
        case .groceries:    return "cart.fill"
        case .dining:       return "fork.knife"
        case .coffee:       return "cup.and.saucer.fill"
        case .transport:    return "car.fill"
        case .shopping:     return "bag.fill"
        case .entertainment: return "film.fill"
        case .health:       return "heart.fill"
        case .bills:        return "doc.text.fill"
        case .education:    return "book.fill"
        case .personal:     return "sparkles"
        case .gifts:        return "gift.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}

// MARK: - PaymentMethod

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash
    case creditCard
    case debitCard
    case applePay
    case venmo
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash:        return "Cash"
        case .creditCard:  return "Credit Card"
        case .debitCard:   return "Debit Card"
        case .applePay:    return "Apple Pay"
        case .venmo:       return "Venmo / Zelle"
        case .other:       return "Other"
        }
    }

    var icon: String {
        switch self {
        case .cash:        return "dollarsign.circle.fill"
        case .creditCard:  return "creditcard.fill"
        case .debitCard:   return "creditcard"
        case .applePay:    return "apple.logo"
        case .venmo:       return "arrow.left.arrow.right.circle.fill"
        case .other:       return "ellipsis.circle"
        }
    }
}

// MARK: - Daily Summary

struct SpendingDaySummary: Identifiable {
    let date: Date
    let entries: [SpendingTrackerEntry]
    let dailyBudget: Double

    var id: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var total: Double {
        entries.reduce(0) { $0 + $1.amount }
    }

    var formattedTotal: String {
        String(format: "$%.2f", total)
    }

    var isUnderBudget: Bool {
        total <= dailyBudget
    }

    var budgetProgress: Double {
        guard dailyBudget > 0 else { return 1.0 }
        return min(total / dailyBudget, 1.0)
    }

    var displayDate: String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Budget Progress State

enum BudgetProgressState {
    case safe        // < 70%
    case warning     // 70–100%
    case exceeded    // > 100%

    init(progress: Double) {
        if progress >= 1.0 {
            self = .exceeded
        } else if progress >= 0.7 {
            self = .warning
        } else {
            self = .safe
        }
    }
}