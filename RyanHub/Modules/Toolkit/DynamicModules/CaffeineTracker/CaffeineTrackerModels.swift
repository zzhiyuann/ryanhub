import Foundation

// MARK: - CaffeineTracker Models

enum CoffeeDrinkType: String, Codable, CaseIterable, Identifiable {
    case espresso
    case drip
    case pourOver
    case coldBrew
    case latte
    case cappuccino
    case americano
    case instantCoffee
    case matcha
    case tea
    case energyDrink
    case decaf
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .espresso: return "Espresso"
        case .drip: return "Drip Coffee"
        case .pourOver: return "Pour Over"
        case .coldBrew: return "Cold Brew"
        case .latte: return "Latte"
        case .cappuccino: return "Cappuccino"
        case .americano: return "Americano"
        case .instantCoffee: return "Instant"
        case .matcha: return "Matcha"
        case .tea: return "Tea"
        case .energyDrink: return "Energy Drink"
        case .decaf: return "Decaf"
        }
    }
    var icon: String {
        switch self {
        case .espresso: return "cup.and.saucer.fill"
        case .drip: return "mug.fill"
        case .pourOver: return "drop.fill"
        case .coldBrew: return "snowflake"
        case .latte: return "cup.and.saucer"
        case .cappuccino: return "cloud.fill"
        case .americano: return "drop.triangle.fill"
        case .instantCoffee: return "bolt.fill"
        case .matcha: return "leaf.fill"
        case .tea: return "leaf"
        case .energyDrink: return "battery.100.bolt"
        case .decaf: return "moon.fill"
        }
    }
}

enum DrinkSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .small: return "Small (8oz)"
        case .medium: return "Medium (12oz)"
        case .large: return "Large (16oz)"
        case .extraLarge: return "XL (20oz)"
        }
    }
    var icon: String {
        switch self {
        case .small: return "s.circle.fill"
        case .medium: return "m.circle.fill"
        case .large: return "l.circle.fill"
        case .extraLarge: return "xmark.circle.fill"
        }
    }
}

struct CaffeineTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var drinkType: CoffeeDrinkType
    var size: DrinkSize
    var caffeineMg: Int
    var time: Date
    var rating: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(drinkType)")
        parts.append("\(size)")
        parts.append("\(caffeineMg)")
        parts.append("\(time)")
        parts.append("\(rating)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
