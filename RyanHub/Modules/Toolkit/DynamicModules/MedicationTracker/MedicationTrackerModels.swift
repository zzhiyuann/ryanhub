import Foundation

// MARK: - MedicationTracker Models

enum DosageUnit: String, Codable, CaseIterable, Identifiable {
    case mg
    case mcg
    case g
    case mL
    case tablets
    case capsules
    case drops
    case puffs
    case units
    case patches
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mg: return "mg"
        case .mcg: return "mcg"
        case .g: return "g"
        case .mL: return "mL"
        case .tablets: return "Tablets"
        case .capsules: return "Capsules"
        case .drops: return "Drops"
        case .puffs: return "Puffs"
        case .units: return "Units"
        case .patches: return "Patches"
        }
    }
    var icon: String {
        switch self {
        case .mg: return "scalemass"
        case .mcg: return "scalemass"
        case .g: return "scalemass.fill"
        case .mL: return "drop.fill"
        case .tablets: return "pills.fill"
        case .capsules: return "capsule.fill"
        case .drops: return "drop"
        case .puffs: return "wind"
        case .units: return "syringe.fill"
        case .patches: return "bandage.fill"
        }
    }
}

enum TimeSlot: String, Codable, CaseIterable, Identifiable {
    case morning
    case midday
    case afternoon
    case evening
    case bedtime
    case asNeeded
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        case .asNeeded: return "As Needed"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .afternoon: return "sun.haze.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.fill"
        case .asNeeded: return "clock.badge.questionmark"
        }
    }
}

enum PostDoseFeeling: String, Codable, CaseIterable, Identifiable {
    case great
    case good
    case neutral
    case unwell
    case bad
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .unwell: return "Unwell"
        case .bad: return "Bad"
        }
    }
    var icon: String {
        switch self {
        case .great: return "face.smiling.inverse"
        case .good: return "face.smiling"
        case .neutral: return "minus.circle"
        case .unwell: return "face.dashed"
        case .bad: return "exclamationmark.triangle.fill"
        }
    }
}

struct MedicationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var medicationName: String
    var dosageAmount: Double
    var dosageUnit: DosageUnit
    var timeSlot: TimeSlot
    var taken: Bool
    var feeling: PostDoseFeeling
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(medicationName)")
        parts.append("\(dosageAmount)")
        parts.append("\(dosageUnit)")
        parts.append("\(timeSlot)")
        parts.append("\(taken)")
        parts.append("\(feeling)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
