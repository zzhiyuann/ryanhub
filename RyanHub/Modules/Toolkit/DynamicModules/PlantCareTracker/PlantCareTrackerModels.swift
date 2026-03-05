import Foundation

// MARK: - PlantCareTracker Models

enum CareType: String, Codable, CaseIterable, Identifiable {
    case watering
    case misting
    case fertilizing
    case pruning
    case repotting
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .watering: return "Watering"
        case .misting: return "Misting"
        case .fertilizing: return "Fertilizing"
        case .pruning: return "Pruning"
        case .repotting: return "Repotting"
        }
    }
    var icon: String {
        switch self {
        case .watering: return "drop.fill"
        case .misting: return "humidity.fill"
        case .fertilizing: return "leaf.arrow.circlepath"
        case .pruning: return "scissors"
        case .repotting: return "arrow.up.bin.fill"
        }
    }
}

enum WaterAmount: String, Codable, CaseIterable, Identifiable {
    case light
    case moderate
    case thorough
    case soaking
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .light: return "Light Splash"
        case .moderate: return "Moderate"
        case .thorough: return "Thorough"
        case .soaking: return "Deep Soak"
        }
    }
    var icon: String {
        switch self {
        case .light: return "drop"
        case .moderate: return "drop.halffull"
        case .thorough: return "drop.fill"
        case .soaking: return "water.waves"
        }
    }
}

enum PlantLocation: String, Codable, CaseIterable, Identifiable {
    case livingRoom
    case bedroom
    case kitchen
    case bathroom
    case office
    case balcony
    case garden
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .kitchen: return "Kitchen"
        case .bathroom: return "Bathroom"
        case .office: return "Office"
        case .balcony: return "Balcony"
        case .garden: return "Garden"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .bedroom: return "bed.double.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "shower.fill"
        case .office: return "desktopcomputer"
        case .balcony: return "sun.max.fill"
        case .garden: return "tree.fill"
        case .other: return "mappin"
        }
    }
}

struct PlantCareTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var plantName: String
    var careType: CareType
    var waterAmount: WaterAmount
    var healthRating: Int
    var location: PlantLocation
    var usedFertilizer: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(plantName)")
        parts.append("\(careType)")
        parts.append("\(waterAmount)")
        parts.append("\(healthRating)")
        parts.append("\(location)")
        parts.append("\(usedFertilizer)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
