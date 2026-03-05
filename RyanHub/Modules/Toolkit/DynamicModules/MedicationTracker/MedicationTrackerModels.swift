import Foundation

// MARK: - Enums

enum DosageUnit: String, CaseIterable, Codable, Identifiable {
    case mg, ml, mcg, tablet, capsule, drop, puff, patch, unit

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mg: return "mg"
        case .ml: return "mL"
        case .mcg: return "mcg"
        case .tablet: return "Tablet"
        case .capsule: return "Capsule"
        case .drop: return "Drops"
        case .puff: return "Puffs"
        case .patch: return "Patch"
        case .unit: return "Units"
        }
    }

    var icon: String {
        switch self {
        case .mg: return "scalemass"
        case .ml: return "drop.fill"
        case .mcg: return "scalemass.fill"
        case .tablet: return "pills.fill"
        case .capsule: return "capsule.fill"
        case .drop: return "drop"
        case .puff: return "wind"
        case .patch: return "bandage.fill"
        case .unit: return "syringe.fill"
        }
    }
}

enum MedicationForm: String, CaseIterable, Codable, Identifiable {
    case pill, capsule, liquid, injection, topical, inhaler, patch, eyeDrops, supplement

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Pill"
        case .capsule: return "Capsule"
        case .liquid: return "Liquid"
        case .injection: return "Injection"
        case .topical: return "Topical"
        case .inhaler: return "Inhaler"
        case .patch: return "Patch"
        case .eyeDrops: return "Eye/Ear Drops"
        case .supplement: return "Supplement"
        }
    }

    var icon: String {
        switch self {
        case .pill: return "pills.fill"
        case .capsule: return "capsule.fill"
        case .liquid: return "drop.fill"
        case .injection: return "syringe.fill"
        case .topical: return "hand.raised.fill"
        case .inhaler: return "wind"
        case .patch: return "bandage.fill"
        case .eyeDrops: return "drop"
        case .supplement: return "leaf.fill"
        }
    }
}

enum DoseStatus: String, CaseIterable, Codable, Identifiable {
    case taken, skipped, missed, delayed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        case .delayed: return "Delayed"
        }
    }

    var icon: String {
        switch self {
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "forward.fill"
        case .missed: return "xmark.circle.fill"
        case .delayed: return "clock.arrow.circlepath"
        }
    }

    var isTaken: Bool { self == .taken }
    var isNonAdherent: Bool { self == .missed || self == .skipped }
}

enum MedicationTimeOfDay: String, CaseIterable, Codable, Identifiable {
    case morning, midday, evening, bedtime, asNeeded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        case .asNeeded: return "As Needed"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.fill"
        case .asNeeded: return "clock.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .midday: return 1
        case .evening: return 2
        case .bedtime: return 3
        case .asNeeded: return 4
        }
    }
}

// MARK: - Entry

struct MedicationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var medicationName: String = ""
    var dosageAmount: Double = 1.0
    var dosageUnit: DosageUnit = .mg
    var medicationForm: MedicationForm = .pill
    var timeOfDay: MedicationTimeOfDay = .morning
    var scheduledTime: Date = Date()
    var status: DoseStatus = .taken
    var withFood: Bool = false
    var sideEffects: String = ""
    var notes: String = ""

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateOnly: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateFormat = "yyyy-MM-dd"
        return out.string(from: d)
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var summaryLine: String {
        let dosageStr = dosageAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(dosageAmount))
            : String(format: "%.1f", dosageAmount)
        return "\(medicationName) \(dosageStr)\(dosageUnit.displayName) — \(status.displayName)"
    }

    var dosageDescription: String {
        let amount = dosageAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(dosageAmount))
            : String(format: "%.1f", dosageAmount)
        return "\(amount) \(dosageUnit.displayName)"
    }

    var hasSideEffects: Bool { !sideEffects.trimmingCharacters(in: .whitespaces).isEmpty }

    var scheduledTimeFormatted: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: scheduledTime)
    }
}

// MARK: - Analytics Helpers

struct MedicationDayStats {
    let date: String
    let takenCount: Int
    let totalCount: Int

    var adherenceRate: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(takenCount) / Double(totalCount)
    }
}

struct MedicationAdherenceSummary {
    let medicationName: String
    let takenCount: Int
    let totalCount: Int

    var adherenceRate: Double {
        guard totalCount > 0 else { return 1.0 }
        return Double(takenCount) / Double(totalCount)
    }

    var adherencePercent: Int { Int((adherenceRate * 100).rounded()) }
    var isBelowThreshold: Bool { adherenceRate < 0.8 }
}