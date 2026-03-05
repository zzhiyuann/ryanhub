import Foundation

// MARK: - PlantCareTracker Models

enum PlantLocation: String, Codable, CaseIterable, Identifiable {
    case livingRoom
    case bedroom
    case kitchen
    case bathroom
    case office
    case balcony
    case windowsill
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .kitchen: return "Kitchen"
        case .bathroom: return "Bathroom"
        case .office: return "Office"
        case .balcony: return "Balcony"
        case .windowsill: return "Windowsill"
        }
    }
    var icon: String {
        switch self {
        case .livingRoom: return "sofa.fill"
        case .bedroom: return "bed.double.fill"
        case .kitchen: return "fork.knife"
        case .bathroom: return "bathtub.fill"
        case .office: return "desktopcomputer"
        case .balcony: return "sun.max.fill"
        case .windowsill: return "window.casement"
        }
    }
}

enum WaterAmount: String, Codable, CaseIterable, Identifiable {
    case lightSplash
    case moderate
    case deepSoak
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lightSplash: return "Light Splash"
        case .moderate: return "Moderate"
        case .deepSoak: return "Deep Soak"
        }
    }
    var icon: String {
        switch self {
        case .lightSplash: return "drop"
        case .moderate: return "drop.fill"
        case .deepSoak: return "humidity.fill"
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
    var location: PlantLocation
    var waterAmount: WaterAmount
    var healthRating: Int
    var fertilized: Bool
    var misted: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(plantName)")
        parts.append("\(location)")
        parts.append("\(waterAmount)")
        parts.append("\(healthRating)")
        parts.append("\(fertilized)")
        parts.append("\(misted)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
