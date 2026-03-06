import Foundation

// MARK: - SpendingCategory

enum SpendingCategory: String, Codable, CaseIterable, Identifiable {
    case food
    case groceries
    case transport
    case shopping
    case entertainment
    case health
    case bills
    case education
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .food: return "Food & Drink"
        case .groceries: return "Groceries"
        case .transport: return "Transport"
        case .shopping: return "Shopping"
        case .entertainment: return "Entertainment"
        case .health: return "Health"
        case .bills: return "Bills & Utilities"
        case .education: return "Education"
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
        case .bills: return "doc.text.fill"
        case .education: return "book.fill"
        case .other: return "ellipsis.circle.fill"
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
    var amount: Double = 0.0
    var category: SpendingCategory = .other
    var note: String = ""

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: d)
    }

    var summaryLine: String {
        let amountStr = String(format: "$%.2f", amount)
        if note.isEmpty {
            return "\(category.displayName) — \(amountStr)"
        }
        return "\(category.displayName) — \(amountStr) — \(note)"
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var dayString: String {
        String(date.prefix(10))
    }

    var timeString: String {
        guard date.count >= 16 else { return "" }
        return String(date.suffix(5))
    }

    var formattedAmount: String {
        String(format: "$%.2f", amount)
    }

    var isToday: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return dayString == f.string(from: Date())
    }
}

// MARK: - CategoryBreakdownItem

struct CategoryBreakdownItem: Identifiable {
    var id: String { category.rawValue }
    let category: SpendingCategory
    let total: Double
    let percentage: Double
}