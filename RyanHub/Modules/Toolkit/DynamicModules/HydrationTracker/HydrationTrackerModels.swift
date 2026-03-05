import Foundation

// MARK: - HydrationTracker Models

enum BeverageType: String, Codable, CaseIterable, Identifiable {
    case water
    case sparklingWater
    case tea
    case herbalTea
    case coffee
    case juice
    case smoothie
    case milk
    case sportsDrink
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .water: return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .tea: return "Tea"
        case .herbalTea: return "Herbal Tea"
        case .coffee: return "Coffee"
        case .juice: return "Juice"
        case .smoothie: return "Smoothie"
        case .milk: return "Milk"
        case .sportsDrink: return "Sports Drink"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .sparklingWater: return "bubble.left.and.bubble.right.fill"
        case .tea: return "leaf.fill"
        case .herbalTea: return "leaf.circle.fill"
        case .coffee: return "cup.and.saucer.fill"
        case .juice: return "carrot.fill"
        case .smoothie: return "blender.fill"
        case .milk: return "cup.and.heat.waves.fill"
        case .sportsDrink: return "bolt.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum ContainerSize: String, Codable, CaseIterable, Identifiable {
    case sip
    case smallGlass
    case glass
    case mug
    case bottle
    case largeBottle
    case custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sip: return "Sip (100ml)"
        case .smallGlass: return "Small Glass (200ml)"
        case .glass: return "Glass (250ml)"
        case .mug: return "Mug (350ml)"
        case .bottle: return "Bottle (500ml)"
        case .largeBottle: return "Large Bottle (750ml)"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .sip: return "drop"
        case .smallGlass: return "drop.halffull"
        case .glass: return "drop.fill"
        case .mug: return "mug.fill"
        case .bottle: return "waterbottle.fill"
        case .largeBottle: return "waterbottle"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum BeverageTemp: String, Codable, CaseIterable, Identifiable {
    case cold
    case warm
    case hot
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cold: return "Cold"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }
    var icon: String {
        switch self {
        case .cold: return "snowflake"
        case .warm: return "thermometer.medium"
        case .hot: return "flame.fill"
        }
    }
}

struct HydrationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amountMl: Int
    var beverageType: BeverageType
    var containerSize: ContainerSize
    var hydrationFactor: Double
    var temperature: BeverageTemp
    var note: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(amountMl)")
        parts.append("\(beverageType)")
        parts.append("\(containerSize)")
        parts.append("\(hydrationFactor)")
        parts.append("\(temperature)")
        return parts.joined(separator: " | ")
    }
}
