import Foundation

// MARK: - CatCareTracker Models

enum EntryType: String, Codable, CaseIterable, Identifiable {
    case feeding
    case vetVisit
    case weightCheck
    case medication
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .feeding: return "Feeding"
        case .vetVisit: return "Vet Visit"
        case .weightCheck: return "Weight Check"
        case .medication: return "Medication"
        }
    }
    var icon: String {
        switch self {
        case .feeding: return "fork.knife"
        case .vetVisit: return "cross.case.fill"
        case .weightCheck: return "scalemass.fill"
        case .medication: return "pill.fill"
        }
    }
}

enum CatMealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack/Treat"
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "sunset.fill"
        case .snack: return "star.fill"
        }
    }
}

enum FoodType: String, Codable, CaseIterable, Identifiable {
    case wetFood
    case dryFood
    case rawFood
    case treats
    case mixed
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .wetFood: return "Wet Food"
        case .dryFood: return "Dry Food"
        case .rawFood: return "Raw Food"
        case .treats: return "Treats"
        case .mixed: return "Mixed"
        }
    }
    var icon: String {
        switch self {
        case .wetFood: return "drop.fill"
        case .dryFood: return "circle.grid.3x3.fill"
        case .rawFood: return "leaf.fill"
        case .treats: return "heart.fill"
        case .mixed: return "square.grid.2x2.fill"
        }
    }
}

enum VisitType: String, Codable, CaseIterable, Identifiable {
    case checkup
    case vaccination
    case illness
    case dental
    case emergency
    case surgery
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .checkup: return "Routine Checkup"
        case .vaccination: return "Vaccination"
        case .illness: return "Illness/Injury"
        case .dental: return "Dental"
        case .emergency: return "Emergency"
        case .surgery: return "Surgery"
        }
    }
    var icon: String {
        switch self {
        case .checkup: return "stethoscope"
        case .vaccination: return "syringe.fill"
        case .illness: return "bandage.fill"
        case .dental: return "mouth.fill"
        case .emergency: return "exclamationmark.triangle.fill"
        case .surgery: return "scissors"
        }
    }
}

struct CatCareTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var entryType: EntryType
    var mealType: CatMealType
    var foodType: FoodType
    var portionSize: Int
    var appetiteLevel: Int
    var visitType: VisitType
    var vetClinic: String
    var cost: Double
    var weightKg: Double
    var medicationGiven: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(entryType)")
        parts.append("\(mealType)")
        parts.append("\(foodType)")
        parts.append("\(portionSize)")
        parts.append("\(appetiteLevel)")
        parts.append("\(visitType)")
        parts.append("\(vetClinic)")
        parts.append("\(cost)")
        parts.append("\(weightKg)")
        parts.append("\(medicationGiven)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
