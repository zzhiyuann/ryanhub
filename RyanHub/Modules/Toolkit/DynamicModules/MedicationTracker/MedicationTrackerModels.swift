import Foundation

// MARK: - Enums

enum MedicationForm: String, CaseIterable, Codable, Identifiable {
    case pill
    case capsule
    case tablet
    case liquid
    case injection
    case inhaler
    case topical
    case drops
    case patch
    case powder

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill:      return "Pill"
        case .capsule:   return "Capsule"
        case .tablet:    return "Tablet"
        case .liquid:    return "Liquid"
        case .injection: return "Injection"
        case .inhaler:   return "Inhaler"
        case .topical:   return "Topical / Cream"
        case .drops:     return "Drops"
        case .patch:     return "Patch"
        case .powder:    return "Powder"
        }
    }

    var icon: String {
        switch self {
        case .pill:      return "pills.fill"
        case .capsule:   return "capsule.fill"
        case .tablet:    return "cross.vial.fill"
        case .liquid:    return "drop.fill"
        case .injection: return "syringe.fill"
        case .inhaler:   return "lungs.fill"
        case .topical:   return "hand.raised.fill"
        case .drops:     return "drop.triangle.fill"
        case .patch:     return "bandage.fill"
        case .powder:    return "aqi.medium"
        }
    }
}

enum DosageUnit: String, CaseIterable, Codable, Identifiable {
    case mg
    case mcg
    case ml
    case units
    case puffs
    case drops
    case tablets
    case patches
    case tsp

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mg:      return "mg"
        case .mcg:     return "mcg"
        case .ml:      return "mL"
        case .units:   return "Units"
        case .puffs:   return "Puffs"
        case .drops:   return "Drops"
        case .tablets: return "Tablets"
        case .patches: return "Patches"
        case .tsp:     return "tsp"
        }
    }

    var icon: String {
        switch self {
        case .mg:      return "scalemass.fill"
        case .mcg:     return "scalemass"
        case .ml:      return "drop.fill"
        case .units:   return "number"
        case .puffs:   return "wind"
        case .drops:   return "drop.triangle.fill"
        case .tablets: return "pills.fill"
        case .patches: return "bandage.fill"
        case .tsp:     return "spoon"
        }
    }
}

enum AdherenceStatus: String, CaseIterable, Codable, Identifiable {
    case onTime
    case late
    case missed
    case skipped

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onTime:  return "On Time"
        case .late:    return "Late"
        case .missed:  return "Missed"
        case .skipped: return "Skipped"
        }
    }

    var icon: String {
        switch self {
        case .onTime:  return "checkmark.circle.fill"
        case .late:    return "clock.badge.exclamationmark.fill"
        case .missed:  return "xmark.circle.fill"
        case .skipped: return "forward.fill"
        }
    }

    /// Returns true if the dose counts as adherent (not missed or skipped)
    var isAdherent: Bool {
        switch self {
        case .onTime, .late: return true
        case .missed, .skipped: return false
        }
    }

    /// Returns true if the dose breaks a streak day
    var breaksStreak: Bool {
        self == .missed
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

    // Data fields
    var medicationName: String = ""
    var dosageAmount: Double = 1.0
    var dosageUnit: DosageUnit = .mg
    var medicationForm: MedicationForm = .pill
    var quantity: Int = 1
    var scheduledTime: Date = Date()
    var adherenceStatus: AdherenceStatus = .onTime
    var withFood: Bool = false
    var sideEffectNoted: Bool = false
    var notes: String = ""

    // MARK: Computed Properties

    /// Parses the stored date string back to a Date, if valid.
    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    /// e.g. "Mar 4, 2026 at 8:30 AM"
    var formattedDate: String {
        guard let d = parsedDate else { return date }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    /// Calendar day string "yyyy-MM-dd" extracted from the stored date.
    var dayKey: String {
        String(date.prefix(10))
    }

    /// Formatted scheduled time, e.g. "8:30 AM"
    var formattedScheduledTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: scheduledTime)
    }

    /// Formatted dosage string, e.g. "500 mg × 2" or "500 mg"
    var dosageLabel: String {
        let amountStr = dosageAmount.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(dosageAmount))
            : String(format: "%.1f", dosageAmount)
        if quantity > 1 {
            return "\(amountStr) \(dosageUnit.displayName) × \(quantity)"
        }
        return "\(amountStr) \(dosageUnit.displayName)"
    }

    /// Short one-line summary for list cells and history.
    var summaryLine: String {
        "\(medicationName) — \(dosageLabel) (\(adherenceStatus.displayName))"
    }

    /// Time slot category for time-of-day analysis.
    var timeSlot: MedicationTimeSlot {
        let hour = Calendar.current.component(.hour, from: scheduledTime)
        switch hour {
        case 5..<12:  return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default:      return .night
        }
    }

    /// True when adherenceStatus is onTime or late.
    var isAdherent: Bool { adherenceStatus.isAdherent }

    /// True when adherenceStatus is missed — used for streak logic.
    var isMissed: Bool { adherenceStatus == .missed }
}

// MARK: - Time Slot

/// Four-slot time-of-day categorization used by analytics and insight generation.
enum MedicationTimeSlot: String, CaseIterable, Codable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        case .night:     return "Night"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .night:     return "moon.stars.fill"
        }
    }

    /// Hour range label, e.g. "5 AM – 12 PM"
    var hourRangeLabel: String {
        switch self {
        case .morning:   return "5 AM – 12 PM"
        case .afternoon: return "12 PM – 5 PM"
        case .evening:   return "5 PM – 9 PM"
        case .night:     return "9 PM – 5 AM"
        }
    }
}

// MARK: - Per-Medication Summary

/// Lightweight value type for per-medication analytics rows.
struct MedicationSummary: Identifiable {
    let id: String          // medication name used as stable ID
    let name: String
    let adherenceRate: Double
    let totalDoses: Int
    let missedDoses: Int
    let sideEffectRate: Double
    let mostCommonForm: MedicationForm?
    let mostCommonUnit: DosageUnit?

    /// True when adherence has dropped below 80% — used to flag alerts.
    var isBelowThreshold: Bool { adherenceRate < 0.80 }

    /// Adherence formatted as a percentage string, e.g. "87%"
    var adherencePercentLabel: String {
        "\(Int((adherenceRate * 100).rounded()))%"
    }
}

// MARK: - Daily Summary

/// Aggregated stats for a single calendar day, used by the history heatmap.
struct DailyMedicationSummary: Identifiable {
    let id: String          // "yyyy-MM-dd" day key
    let date: Date
    let entries: [MedicationTrackerEntry]

    var totalDoses: Int { entries.count }

    var adherentDoses: Int { entries.filter(\.isAdherent).count }

    var missedDoses: Int { entries.filter(\.isMissed).count }

    /// 0.0 – 1.0. Returns 1.0 when no entries exist (no data, not a failure).
    var adherenceRate: Double {
        guard totalDoses > 0 else { return 1.0 }
        return Double(adherentDoses) / Double(totalDoses)
    }

    /// True when zero doses were logged (treated as full miss for streak logic).
    var isEmpty: Bool { entries.isEmpty }

    /// A day is streak-valid if it has at least one entry and zero missed doses.
    var isStreakValid: Bool {
        !isEmpty && missedDoses == 0
    }

    /// Heatmap color semantic based on adherence rate.
    var heatmapLevel: HeatmapLevel {
        if isEmpty            { return .noData }
        if adherenceRate >= 1.0 { return .perfect }
        if adherenceRate >= 0.5 { return .partial }
        return .poor
    }
}

// MARK: - Heatmap Level

enum HeatmapLevel: String, CaseIterable {
    case noData
    case perfect
    case partial
    case poor

    /// Semantic color name mapping to the Ryan Hub design system.
    var colorName: String {
        switch self {
        case .noData:   return "surfaceSecondary"
        case .perfect:  return "hubAccentGreen"
        case .partial:  return "hubAccentYellow"
        case .poor:     return "hubAccentRed"
        }
    }

    var label: String {
        switch self {
        case .noData:   return "No Data"
        case .perfect:  return "100%"
        case .partial:  return "Partial"
        case .poor:     return "Low"
        }
    }
}