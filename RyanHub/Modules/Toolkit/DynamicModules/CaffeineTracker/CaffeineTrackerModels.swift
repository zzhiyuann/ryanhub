import Foundation

// MARK: - CaffeineTracker Models

enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case espresso
    case drip
    case pourOver
    case coldBrew
    case latte
    case cappuccino
    case americano
    case greenTea
    case blackTea
    case energyDrink
    case matcha
    case other
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
        case .greenTea: return "Green Tea"
        case .blackTea: return "Black Tea"
        case .energyDrink: return "Energy Drink"
        case .matcha: return "Matcha"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .espresso: return "cup.and.saucer.fill"
        case .drip: return "mug.fill"
        case .pourOver: return "drop.fill"
        case .coldBrew: return "snowflake"
        case .latte: return "cup.and.saucer.fill"
        case .cappuccino: return "cup.and.saucer.fill"
        case .americano: return "mug.fill"
        case .greenTea: return "leaf.fill"
        case .blackTea: return "leaf.fill"
        case .energyDrink: return "bolt.fill"
        case .matcha: return "leaf.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum DrinkSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge
    case shot
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .small: return "Small (8oz)"
        case .medium: return "Medium (12oz)"
        case .large: return "Large (16oz)"
        case .extraLarge: return "XL (20oz)"
        case .shot: return "Shot (1oz)"
        }
    }
    var icon: String {
        switch self {
        case .small: return "s.circle.fill"
        case .medium: return "m.circle.fill"
        case .large: return "l.circle.fill"
        case .extraLarge: return "xl.circle.fill"
        case .shot: return "drop.circle.fill"
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
    var drinkType: DrinkType
    var size: DrinkSize
    var caffeineMg: Int
    var shots: Int
    var time: Date
    var cost: Double
    var isDecaf: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(drinkType)")
        parts.append("\(size)")
        parts.append("\(caffeineMg)")
        parts.append("\(shots)")
        parts.append("\(time)")
        parts.append("\(cost)")
        parts.append("\(isDecaf)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
