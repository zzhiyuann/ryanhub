import Foundation

// MARK: - GroceryList Models

enum GroceryCategory: String, Codable, CaseIterable, Identifiable {
    case produce
    case dairy
    case meat
    case seafood
    case bakery
    case frozen
    case beverages
    case snacks
    case condiments
    case grains
    case household
    case personalCare
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .produce: return "Produce"
        case .dairy: return "Dairy & Eggs"
        case .meat: return "Meat & Poultry"
        case .seafood: return "Seafood"
        case .bakery: return "Bakery & Bread"
        case .frozen: return "Frozen Foods"
        case .beverages: return "Beverages"
        case .snacks: return "Snacks & Sweets"
        case .condiments: return "Condiments & Sauces"
        case .grains: return "Grains & Pasta"
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
        case .seafood: return "fish.fill"
        case .bakery: return "birthday.cake.fill"
        case .frozen: return "snowflake"
        case .beverages: return "waterbottle.fill"
        case .snacks: return "popcorn.fill"
        case .condiments: return "takeoutbag.and.cup.and.straw.fill"
        case .grains: return "grain"
        case .household: return "house.fill"
        case .personalCare: return "heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum MeasurementUnit: String, Codable, CaseIterable, Identifiable {
    case pieces
    case lbs
    case oz
    case kg
    case liters
    case gallons
    case packs
    case bags
    case boxes
    case cans
    case bottles
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .pieces: return "Pieces"
        case .lbs: return "Pounds"
        case .oz: return "Ounces"
        case .kg: return "Kilograms"
        case .liters: return "Liters"
        case .gallons: return "Gallons"
        case .packs: return "Packs"
        case .bags: return "Bags"
        case .boxes: return "Boxes"
        case .cans: return "Cans"
        case .bottles: return "Bottles"
        }
    }
    var icon: String {
        switch self {
        case .pieces: return "number"
        case .lbs: return "scalemass.fill"
        case .oz: return "scalemass"
        case .kg: return "scalemass.fill"
        case .liters: return "drop.fill"
        case .gallons: return "drop.fill"
        case .packs: return "shippingbox.fill"
        case .bags: return "bag.fill"
        case .boxes: return "archivebox.fill"
        case .cans: return "cylinder.fill"
        case .bottles: return "waterbottle.fill"
        }
    }
}

enum ItemPriority: String, Codable, CaseIterable, Identifiable {
    case essential
    case preferred
    case optional
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .essential: return "Essential"
        case .preferred: return "Preferred"
        case .optional: return "Optional"
        }
    }
    var icon: String {
        switch self {
        case .essential: return "exclamationmark.circle.fill"
        case .preferred: return "star.fill"
        case .optional: return "questionmark.circle.fill"
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
    var itemName: String
    var category: GroceryCategory
    var quantity: Int
    var unit: MeasurementUnit
    var estimatedPrice: Double
    var isChecked: Bool
    var priority: ItemPriority
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(itemName)")
        parts.append("\(category)")
        parts.append("\(quantity)")
        parts.append("\(unit)")
        parts.append("\(estimatedPrice)")
        parts.append("\(isChecked)")
        parts.append("\(priority)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
