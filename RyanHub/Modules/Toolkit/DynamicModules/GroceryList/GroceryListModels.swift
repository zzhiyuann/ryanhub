import Foundation

// MARK: - GroceryList Models

enum GroceryUnit: String, Codable, CaseIterable, Identifiable {
    case pieces
    case lbs
    case oz
    case kg
    case grams
    case liters
    case gallons
    case dozen
    case pack
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pieces: return "pcs"
        case .lbs: return "lbs"
        case .oz: return "oz"
        case .kg: return "kg"
        case .grams: return "g"
        case .liters: return "L"
        case .gallons: return "gal"
        case .dozen: return "doz"
        case .pack: return "pack"
        }
    }
    var icon: String {
        switch self {
        case .pieces: return "number"
        case .lbs: return "scalemass"
        case .oz: return "scalemass"
        case .kg: return "scalemass"
        case .grams: return "scalemass"
        case .liters: return "drop.fill"
        case .gallons: return "drop.fill"
        case .dozen: return "circle.grid.3x3"
        case .pack: return "shippingbox"
        }
    }
}

enum GroceryCategory: String, Codable, CaseIterable, Identifiable {
    case produce
    case dairy
    case meatSeafood
    case bakery
    case frozen
    case pantry
    case beverages
    case snacks
    case household
    case personalCare
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .meatSeafood: return "Meat & Seafood"
        case .bakery: return "Bakery"
        case .frozen: return "Frozen"
        case .pantry: return "Pantry & Dry Goods"
        case .beverages: return "Beverages"
        case .snacks: return "Snacks"
        case .household: return "Household"
        case .personalCare: return "Personal Care"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .produce: return "leaf.fill"
        case .dairy: return "cup.and.saucer.fill"
        case .meatSeafood: return "fork.knife"
        case .bakery: return "birthday.cake"
        case .frozen: return "snowflake"
        case .pantry: return "archivebox.fill"
        case .beverages: return "wineglass.fill"
        case .snacks: return "bag.fill"
        case .household: return "house.fill"
        case .personalCare: return "sparkles"
        case .other: return "ellipsis.circle"
        }
    }
}

struct GroceryListEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var name: String
    var quantity: Int
    var unit: GroceryUnit
    var category: GroceryCategory
    var isChecked: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(name)")
        parts.append("\(quantity)")
        parts.append("\(unit)")
        parts.append("\(category)")
        parts.append("\(isChecked)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
