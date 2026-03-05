import Foundation

// MARK: - Enums

enum GroceryCategory: String, CaseIterable, Codable, Identifiable {
    case produce, dairy, meat, bakery, frozen, beverages, snacks, pantry, household, personalCare, other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .meat: return "Meat & Seafood"
        case .bakery: return "Bakery"
        case .frozen: return "Frozen"
        case .beverages: return "Beverages"
        case .snacks: return "Snacks"
        case .pantry: return "Pantry & Canned"
        case .household: return "Household"
        case .personalCare: return "Personal Care"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .meat: return "fork.knife"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .beverages: return "waterbottle.fill"
        case .snacks: return "popcorn.fill"
        case .pantry: return "cabinet.fill"
        case .household: return "house.fill"
        case .personalCare: return "heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .produce: return 0
        case .dairy: return 1
        case .meat: return 2
        case .bakery: return 3
        case .frozen: return 4
        case .beverages: return 5
        case .snacks: return 6
        case .pantry: return 7
        case .household: return 8
        case .personalCare: return 9
        case .other: return 10
        }
    }
}

enum GroceryUnit: String, CaseIterable, Codable, Identifiable {
    case piece, lb, oz, gallon, liter, pack, bag, box, bunch, dozen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .piece: return "Piece"
        case .lb: return "lb"
        case .oz: return "oz"
        case .gallon: return "Gallon"
        case .liter: return "Liter"
        case .pack: return "Pack"
        case .bag: return "Bag"
        case .box: return "Box"
        case .bunch: return "Bunch"
        case .dozen: return "Dozen"
        }
    }

    var icon: String {
        switch self {
        case .piece: return "circlebadge.fill"
        case .lb: return "scalemass.fill"
        case .oz: return "scalemass"
        case .gallon: return "drop.fill"
        case .liter: return "drop.fill"
        case .pack: return "shippingbox.fill"
        case .bag: return "bag.fill"
        case .box: return "archivebox.fill"
        case .bunch: return "leaf.fill"
        case .dozen: return "circle.grid.3x3.fill"
        }
    }

    var abbreviation: String {
        switch self {
        case .piece: return "pc"
        case .lb: return "lb"
        case .oz: return "oz"
        case .gallon: return "gal"
        case .liter: return "L"
        case .pack: return "pk"
        case .bag: return "bg"
        case .box: return "bx"
        case .bunch: return "bn"
        case .dozen: return "dz"
        }
    }
}

enum GroceryPriority: String, CaseIterable, Codable, Identifiable {
    case essential, needed, optional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essential: return "Essential"
        case .needed: return "Needed"
        case .optional: return "Nice to Have"
        }
    }

    var icon: String {
        switch self {
        case .essential: return "exclamationmark.circle.fill"
        case .needed: return "arrow.up.circle.fill"
        case .optional: return "minus.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .essential: return 0
        case .needed: return 1
        case .optional: return 2
        }
    }
}

// MARK: - Main Entry

struct GroceryListEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var itemName: String = ""
    var category: GroceryCategory = .other
    var quantity: Int = 1
    var unit: GroceryUnit = .piece
    var estimatedPrice: Double = 0.0
    var isPurchased: Bool = false
    var priority: GroceryPriority = .needed
    var notes: String = ""

    // MARK: - Formatted Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateOnly: String {
        String(date.prefix(10))
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    /// e.g. "2x Whole Milk (Dairy) — $3.99"
    var summaryLine: String {
        let priceStr = estimatedPrice > 0 ? " — $\(String(format: "%.2f", estimatedPrice))" : ""
        return "\(quantity)\(unit.abbreviation) \(itemName) (\(category.displayName))\(priceStr)"
    }

    /// Total cost for this line item: quantity × estimatedPrice
    var lineTotal: Double {
        Double(quantity) * estimatedPrice
    }

    var formattedLineTotal: String {
        "$\(String(format: "%.2f", lineTotal))"
    }

    var formattedEstimatedPrice: String {
        "$\(String(format: "%.2f", estimatedPrice))"
    }

    var quantityWithUnit: String {
        "\(quantity) \(unit.displayName)\(quantity > 1 && unit == .piece ? "s" : "")"
    }

    var isHighPriority: Bool {
        priority == .essential
    }
}

// MARK: - Shopping Trip Summary

struct GroceryShoppingTrip: Identifiable {
    let id: String
    let dateString: String
    let entries: [GroceryListEntry]

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dateString)
    }

    var formattedDate: String {
        guard let d = parsedDate else { return dateString }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: d)
    }

    var totalItems: Int { entries.count }
    var purchasedCount: Int { entries.filter(\.isPurchased).count }
    var completionRate: Double {
        guard totalItems > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalItems) * 100
    }

    var totalSpend: Double {
        entries.filter(\.isPurchased).reduce(0) { $0 + $1.lineTotal }
    }

    var estimatedTotal: Double {
        entries.reduce(0) { $0 + $1.lineTotal }
    }

    var formattedTotalSpend: String {
        "$\(String(format: "%.2f", totalSpend))"
    }

    var allEssentialsPurchased: Bool {
        entries.filter { $0.priority == .essential }.allSatisfy(\.isPurchased)
    }
}

// MARK: - Category Spending

struct GroceryCategorySpend: Identifiable {
    let id: String
    let category: GroceryCategory
    let total: Double
    let percentage: Double

    var formattedTotal: String { "$\(String(format: "%.2f", total))" }
    var formattedPercentage: String { "\(String(format: "%.0f", percentage))%" }
}

// MARK: - Frequently Bought Item

struct GroceryFrequentItem: Identifiable {
    let id: String
    let itemName: String
    let count: Int
    let lastCategory: GroceryCategory
}