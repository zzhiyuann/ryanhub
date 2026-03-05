import Foundation

// MARK: - HydrationTracker Models

enum DrinkType: String, Codable, CaseIterable, Identifiable {
    case water
    case sparklingWater
    case tea
    case coffee
    case juice
    case milk
    case smoothie
    case sportsDrink
    case soup
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .water: return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .tea: return "Tea"
        case .coffee: return "Coffee"
        case .juice: return "Juice"
        case .milk: return "Milk"
        case .smoothie: return "Smoothie"
        case .sportsDrink: return "Sports Drink"
        case .soup: return "Soup"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .tea: return "cup.and.saucer.fill"
        case .coffee: return "mug.fill"
        case .juice: return "carrot.fill"
        case .milk: return "cup.and.heat.waves.fill"
        case .smoothie: return "blender.fill"
        case .sportsDrink: return "bolt.fill"
        case .soup: return "takeoutbag.and.cup.and.straw.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum ContainerSize: String, Codable, CaseIterable, Identifiable {
    case sip
    case small
    case medium
    case large
    case bottle
    case largeBottle
    case custom
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sip: return "Sip (100ml)"
        case .small: return "Small Glass (200ml)"
        case .medium: return "Glass (250ml)"
        case .large: return "Large Glass (350ml)"
        case .bottle: return "Bottle (500ml)"
        case .largeBottle: return "Large Bottle (750ml)"
        case .custom: return "Custom"
        }
    }
    var icon: String {
        switch self {
        case .sip: return "drop"
        case .small: return "drop.halffull"
        case .medium: return "drop.fill"
        case .large: return "waterbottle"
        case .bottle: return "waterbottle.fill"
        case .largeBottle: return "takeoutbag.and.cup.and.straw.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
}

enum DrinkTemperature: String, Codable, CaseIterable, Identifiable {
    case cold
    case roomTemp
    case warm
    case hot
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .cold: return "Cold"
        case .roomTemp: return "Room Temp"
        case .warm: return "Warm"
        case .hot: return "Hot"
        }
    }
    var icon: String {
        switch self {
        case .cold: return "snowflake"
        case .roomTemp: return "thermometer.medium"
        case .warm: return "flame"
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
    var amount: Int
    var drinkType: DrinkType
    var containerSize: ContainerSize
    var caffeinated: Bool
    var temperature: DrinkTemperature
    var time: Date
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(amount)")
        parts.append("\(drinkType)")
        parts.append("\(containerSize)")
        parts.append("\(caffeinated)")
        parts.append("\(temperature)")
        parts.append("\(time)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
