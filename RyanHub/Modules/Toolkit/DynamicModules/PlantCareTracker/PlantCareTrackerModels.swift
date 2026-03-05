import Foundation

// MARK: - Enums

enum CareType: String, CaseIterable, Codable, Identifiable {
    case water
    case fertilize
    case mist
    case prune
    case repot
    case rotate

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .fertilize: return "Fertilize"
        case .mist: return "Mist"
        case .prune: return "Prune"
        case .repot: return "Repot"
        case .rotate: return "Rotate"
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .fertilize: return "leaf.arrow.circlepath"
        case .mist: return "humidity.fill"
        case .prune: return "scissors"
        case .repot: return "arrow.3.trianglepath"
        case .rotate: return "arrow.triangle.2.circlepath"
        }
    }
}

enum WaterAmount: String, CaseIterable, Codable, Identifiable {
    case light
    case moderate
    case thorough

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light Splash"
        case .moderate: return "Moderate"
        case .thorough: return "Thorough Soak"
        }
    }

    var icon: String {
        switch self {
        case .light: return "drop"
        case .moderate: return "drop.fill"
        case .thorough: return "drop.circle.fill"
        }
    }
}

enum SoilMoisture: String, CaseIterable, Codable, Identifiable {
    case dry
    case slightlyMoist
    case moist
    case wet

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dry: return "Bone Dry"
        case .slightlyMoist: return "Slightly Moist"
        case .moist: return "Moist"
        case .wet: return "Soggy / Wet"
        }
    }

    var icon: String {
        switch self {
        case .dry: return "sun.max.fill"
        case .slightlyMoist: return "drop"
        case .moist: return "drop.fill"
        case .wet: return "water.waves"
        }
    }
}

enum PlantLocation: String, CaseIterable, Codable, Identifiable {
    case windowsill
    case balcony
    case livingRoom
    case bedroom
    case bathroom
    case kitchen
    case office

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .windowsill: return "Windowsill"
        case .balcony: return "Balcony"
        case .livingRoom: return "Living Room"
        case .bedroom: return "Bedroom"
        case .bathroom: return "Bathroom"
        case .kitchen: return "Kitchen"
        case .office: return "Office"
        }
    }

    var icon: String {
        switch self {
        case .windowsill: return "sun.max"
        case .balcony: return "tree.fill"
        case .livingRoom: return "sofa.fill"
        case .bedroom: return "bed.double.fill"
        case .bathroom: return "bathtub.fill"
        case .kitchen: return "fork.knife"
        case .office: return "desktopcomputer"
        }
    }
}

// MARK: - Entry

struct PlantCareTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var plantName: String = ""
    var careType: CareType = .water
    var waterAmount: WaterAmount = .moderate
    var healthScore: Int = 3
    var soilMoisture: SoilMoisture = .moist
    var location: PlantLocation = .livingRoom
    var notes: String = ""

    // MARK: Computed — Date

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    var dateOnly: String {
        String(date.prefix(10))
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var formattedDateShort: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .short
        out.timeStyle = .none
        return out.string(from: d)
    }

    // MARK: Computed — Display

    var summaryLine: String {
        var parts: [String] = [careType.displayName]
        if !plantName.isEmpty { parts.insert(plantName, at: 0) }
        return parts.joined(separator: " — ")
    }

    var healthScoreLabel: String {
        switch healthScore {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "\(healthScore)"
        }
    }

    var healthScoreIcon: String {
        switch healthScore {
        case 1, 2: return "heart.slash.fill"
        case 3: return "heart.fill"
        case 4, 5: return "heart.circle.fill"
        default: return "heart"
        }
    }

    var isWaterEvent: Bool {
        careType == .water
    }

    var waterAmountDescription: String {
        isWaterEvent ? waterAmount.displayName : "N/A"
    }

    var displayPlantName: String {
        plantName.isEmpty ? "Unknown Plant" : plantName
    }
}

// MARK: - Sample Data

extension PlantCareTrackerEntry {
    static func sample(plantName: String = "Monstera", careType: CareType = .water, daysAgo: Int = 0) -> PlantCareTrackerEntry {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        let d = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return PlantCareTrackerEntry(
            id: UUID().uuidString,
            date: f.string(from: d),
            plantName: plantName,
            careType: careType,
            waterAmount: .moderate,
            healthScore: Int.random(in: 3...5),
            soilMoisture: .moist,
            location: .livingRoom,
            notes: ""
        )
    }

    static var samples: [PlantCareTrackerEntry] {
        [
            .sample(plantName: "Monstera", careType: .water, daysAgo: 0),
            .sample(plantName: "Pothos", careType: .mist, daysAgo: 0),
            .sample(plantName: "Snake Plant", careType: .water, daysAgo: 1),
            .sample(plantName: "Fiddle Leaf Fig", careType: .fertilize, daysAgo: 2),
            .sample(plantName: "ZZ Plant", careType: .rotate, daysAgo: 3),
            .sample(plantName: "Monstera", careType: .water, daysAgo: 8)
        ]
    }
}