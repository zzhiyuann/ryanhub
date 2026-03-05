import Foundation

// MARK: - Entry Model

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
    var unit: ItemUnit = .pieces
    var estimatedPrice: Double = 0.0
    var priority: ItemPriority = .preferred
    var isChecked: Bool = false
    var notes: String = ""

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

    var dateValue: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var dayKey: String {
        String(date.prefix(10))
    }

    var subtotal: Double {
        estimatedPrice * Double(quantity)
    }

    var summaryLine: String {
        let qty = "\(quantity) \(unit.displayName)"
        let price = String(format: "$%.2f", subtotal)
        return "\(qty) · \(price) · \(category.displayName)"
    }

    var priorityBadge: String {
        switch priority {
        case .essential: return "!"
        case .preferred: return "★"
        case .optional: return "?"
        }
    }
}

// MARK: - GroceryCategory

enum GroceryCategory: String, CaseIterable, Codable, Identifiable {
    case produce
    case dairy
    case meat
    case bakery
    case frozen
    case beverages
    case snacks
    case grains
    case condiments
    case household
    case personalCare
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .produce:      return "Produce"
        case .dairy:        return "Dairy & Eggs"
        case .meat:         return "Meat & Seafood"
        case .bakery:       return "Bakery"
        case .frozen:       return "Frozen"
        case .beverages:    return "Beverages"
        case .snacks:       return "Snacks"
        case .grains:       return "Grains & Pasta"
        case .condiments:   return "Condiments & Sauces"
        case .household:    return "Household"
        case .personalCare: return "Personal Care"
        case .other:        return "Other"
        }
    }

    var icon: String {
        switch self {
        case .produce:      return "leaf.fill"
        case .dairy:        return "cup.and.saucer.fill"
        case .meat:         return "flame.fill"
        case .bakery:       return "birthday.cake.fill"
        case .frozen:       return "snowflake"
        case .beverages:    return "mug.fill"
        case .snacks:       return "bag.fill"
        case .grains:       return "basket.fill"
        case .condiments:   return "fork.knife"
        case .household:    return "house.fill"
        case .personalCare: return "heart.fill"
        case .other:        return "ellipsis.circle.fill"
        }
    }
}

// MARK: - ItemUnit

enum ItemUnit: String, CaseIterable, Codable, Identifiable {
    case pieces
    case lbs
    case oz
    case kg
    case liters
    case gallons
    case packs
    case bags
    case bottles
    case boxes

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pieces:  return "Pieces"
        case .lbs:     return "Pounds"
        case .oz:      return "Ounces"
        case .kg:      return "Kilograms"
        case .liters:  return "Liters"
        case .gallons: return "Gallons"
        case .packs:   return "Packs"
        case .bags:    return "Bags"
        case .bottles: return "Bottles"
        case .boxes:   return "Boxes"
        }
    }

    var icon: String {
        switch self {
        case .pieces:  return "number"
        case .lbs:     return "scalemass.fill"
        case .oz:      return "scalemass"
        case .kg:      return "lineweight"
        case .liters:  return "drop.fill"
        case .gallons: return "drop.circle.fill"
        case .packs:   return "shippingbox.fill"
        case .bags:    return "bag.fill"
        case .bottles: return "waterbottle.fill"
        case .boxes:   return "archivebox.fill"
        }
    }

    var abbreviation: String {
        switch self {
        case .pieces:  return "pc"
        case .lbs:     return "lb"
        case .oz:      return "oz"
        case .kg:      return "kg"
        case .liters:  return "L"
        case .gallons: return "gal"
        case .packs:   return "pk"
        case .bags:    return "bag"
        case .bottles: return "btl"
        case .boxes:   return "box"
        }
    }
}

// MARK: - ItemPriority

enum ItemPriority: String, CaseIterable, Codable, Identifiable {
    case essential
    case preferred
    case optional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .essential: return "Essential"
        case .preferred: return "Preferred"
        case .optional:  return "Optional"
        }
    }

    var icon: String {
        switch self {
        case .essential: return "exclamationmark.circle.fill"
        case .preferred: return "star.fill"
        case .optional:  return "questionmark.circle.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .essential: return 0
        case .preferred: return 1
        case .optional:  return 2
        }
    }
}

// MARK: - Shopping Trip (History Aggregate)

struct GroceryShoppingTrip: Identifiable {
    let id: String
    let date: Date
    let dayKey: String
    let items: [GroceryListEntry]

    var totalSpend: Double {
        items.filter(\.isChecked).reduce(0) { $0 + $1.subtotal }
    }

    var itemCount: Int { items.count }

    var purchasedCount: Int { items.filter(\.isChecked).count }

    var completionRate: Double {
        guard itemCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(itemCount)
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}

// MARK: - Helpers

extension Collection where Element == GroceryListEntry {
    var totalEstimatedCost: Double {
        reduce(0) { $0 + $1.subtotal }
    }

    func groupedByCategory() -> [GroceryCategory: [GroceryListEntry]] {
        Dictionary(grouping: self, by: \.category)
    }

    func groupedByDay() -> [String: [GroceryListEntry]] {
        Dictionary(grouping: self, by: \.dayKey)
    }
}