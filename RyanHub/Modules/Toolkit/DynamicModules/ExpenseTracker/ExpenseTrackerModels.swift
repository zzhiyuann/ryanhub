import Foundation

// MARK: - Enums

enum ExpenseCategory: String, CaseIterable, Codable, Identifiable {
    case food
    case transport
    case housing
    case utilities
    case entertainment
    case shopping
    case health
    case education
    case subscriptions
    case personal
    case gifts
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food & Dining"
        case .transport: return "Transport"
        case .housing: return "Housing"
        case .utilities: return "Utilities"
        case .entertainment: return "Entertainment"
        case .shopping: return "Shopping"
        case .health: return "Health"
        case .education: return "Education"
        case .subscriptions: return "Subscriptions"
        case .personal: return "Personal Care"
        case .gifts: return "Gifts & Donations"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .transport: return "car.fill"
        case .housing: return "house.fill"
        case .utilities: return "bolt.fill"
        case .entertainment: return "film.fill"
        case .shopping: return "bag.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .personal: return "sparkles"
        case .gifts: return "gift.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum PaymentMethod: String, CaseIterable, Codable, Identifiable {
    case cash
    case creditCard
    case debitCard
    case digitalWallet
    case bankTransfer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cash: return "Cash"
        case .creditCard: return "Credit Card"
        case .debitCard: return "Debit Card"
        case .digitalWallet: return "Digital Wallet"
        case .bankTransfer: return "Bank Transfer"
        }
    }

    var icon: String {
        switch self {
        case .cash: return "banknote.fill"
        case .creditCard: return "creditcard.fill"
        case .debitCard: return "creditcard"
        case .digitalWallet: return "iphone.gen3"
        case .bankTransfer: return "building.columns.fill"
        }
    }
}

// MARK: - Budget Entry

struct CategoryBudget: Codable, Identifiable {
    var id: String { category.rawValue }
    var category: ExpenseCategory
    var monthlyLimit: Double

    init(category: ExpenseCategory, monthlyLimit: Double) {
        self.category = category
        self.monthlyLimit = monthlyLimit
    }
}

// MARK: - Main Entry

struct ExpenseTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var amount: Double = 0.0
    var category: ExpenseCategory = .other
    var paymentMethod: PaymentMethod = .cash
    var merchant: String = ""
    var note: String = ""
    var isRecurring: Bool = false

    // MARK: Computed — Date

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: parsedDate)
    }

    var dateOnlyString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: parsedDate)
    }

    var timeString: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: parsedDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(parsedDate)
    }

    var isThisWeek: Bool {
        Calendar.current.isDate(parsedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    var isThisMonth: Bool {
        Calendar.current.isDate(parsedDate, equalTo: Date(), toGranularity: .month)
    }

    // MARK: Computed — Display

    var formattedAmount: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: NSNumber(value: amount)) ?? "$\(String(format: "%.2f", amount))"
    }

    var summaryLine: String {
        let merchantPart = merchant.isEmpty ? category.displayName : merchant
        return "\(formattedAmount) · \(merchantPart)"
    }

    var detailLine: String {
        var parts: [String] = [category.displayName, paymentMethod.displayName]
        if !note.isEmpty { parts.append(note) }
        return parts.joined(separator: " · ")
    }

    var recurringBadge: String? {
        isRecurring ? "Recurring" : nil
    }
}

// MARK: - Module Settings

struct ExpenseTrackerSettings: Codable {
    var monthlyBudget: Double = 3000.0
    var categoryBudgets: [CategoryBudget] = []
    var currencyCode: String = "USD"
    var defaultPaymentMethod: PaymentMethod = .creditCard

    var dailyBudgetTarget: Double {
        let days = Calendar.current.range(of: .day, in: .month, for: Date())?.count ?? 30
        return monthlyBudget / Double(days)
    }

    func budget(for category: ExpenseCategory) -> Double? {
        categoryBudgets.first(where: { $0.category == category })?.monthlyLimit
    }
}

// MARK: - Aggregate Helpers

struct DailySpendingPoint: Identifiable {
    var id: String { date }
    var date: String
    var total: Double
    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: date) ?? Date()
    }
}

struct WeeklySpendingPoint: Identifiable {
    var id: String { weekLabel }
    var weekLabel: String
    var total: Double
}

struct CategoryBreakdownPoint: Identifiable {
    var id: String { category.rawValue }
    var category: ExpenseCategory
    var total: Double
    var percentage: Double
}

struct BudgetProgressPoint: Identifiable {
    var id: String { category.rawValue }
    var category: ExpenseCategory
    var spent: Double
    var budget: Double
    var percentage: Double

    var isOverBudget: Bool { spent > budget }
    var isNearLimit: Bool { percentage >= 0.80 && !isOverBudget }
    var remaining: Double { max(0, budget - spent) }
}