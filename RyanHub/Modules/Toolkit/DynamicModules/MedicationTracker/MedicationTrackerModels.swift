import SwiftUI

// MARK: - Main Entry

struct MedicationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var name: String = ""
    var dosage: String = ""
    var form: MedicationForm = .pill
    var frequency: DoseFrequency = .onceDaily
    var primaryTime: Date = Date()
    var color: MedicationColor = .blue
    var instructions: String = ""
    var supplyCount: Int = 30
    var isActive: Bool = true

    // MARK: Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    var summaryLine: String {
        "\(name) \(dosage) — \(frequency.displayName)"
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: primaryTime)
    }

    var dailyDoseCount: Int {
        frequency.dosesPerDay
    }

    var estimatedSupplyDays: Int {
        let daily = dailyDoseCount
        guard daily > 0 else { return supplyCount }
        return supplyCount / daily
    }

    var isLowSupply: Bool {
        estimatedSupplyDays < 7
    }

    var colorValue: Color {
        color.swiftUIColor
    }
}

// MARK: - Scheduled Dose

struct ScheduledDose: Identifiable {
    let id: String
    let medication: MedicationTrackerEntry
    let scheduledTime: Date
    var status: DoseStatus
    var takenTime: Date?

    var timeSlot: TimeSlot {
        let hour = Calendar.current.component(.hour, from: scheduledTime)
        switch hour {
        case 5..<12: return .morning
        case 12..<17: return .afternoon
        case 17..<21: return .evening
        default: return .bedtime
        }
    }

    var formattedScheduledTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: scheduledTime)
    }

    var isOverdue: Bool {
        status == .due && Date() > scheduledTime.addingTimeInterval(30 * 60)
    }

    var isDueNow: Bool {
        status == .upcoming || status == .due
    }
}

// MARK: - Day Adherence

struct DayAdherence: Identifiable {
    let id: String
    let date: Date
    let taken: Int
    let total: Int
    let details: [ScheduledDose]

    var rate: Double {
        guard total > 0 else { return 1.0 }
        return Double(taken) / Double(total)
    }

    var isPerfect: Bool {
        rate >= 1.0
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }

    var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Time Slot

enum TimeSlot: String, CaseIterable, Codable, Identifiable {
    case morning
    case afternoon
    case evening
    case bedtime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.fill"
        }
    }

    var hourRange: Range<Int> {
        switch self {
        case .morning: return 5..<12
        case .afternoon: return 12..<17
        case .evening: return 17..<21
        case .bedtime: return 21..<29
        }
    }
}

// MARK: - Medication Form

enum MedicationForm: String, CaseIterable, Codable, Identifiable {
    case pill
    case capsule
    case liquid
    case injection
    case inhaler
    case topical
    case patch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pill: return "Pill"
        case .capsule: return "Capsule"
        case .liquid: return "Liquid"
        case .injection: return "Injection"
        case .inhaler: return "Inhaler"
        case .topical: return "Topical"
        case .patch: return "Patch"
        }
    }

    var icon: String {
        switch self {
        case .pill: return "pill.fill"
        case .capsule: return "capsule.fill"
        case .liquid: return "drop.fill"
        case .injection: return "syringe.fill"
        case .inhaler: return "lungs.fill"
        case .topical: return "hand.raised.fill"
        case .patch: return "bandage.fill"
        }
    }
}

// MARK: - Dose Frequency

enum DoseFrequency: String, CaseIterable, Codable, Identifiable {
    case onceDaily
    case twiceDaily
    case threeTimesDaily
    case fourTimesDaily
    case everyOtherDay
    case weekly
    case asNeeded

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .onceDaily: return "Once Daily"
        case .twiceDaily: return "Twice Daily"
        case .threeTimesDaily: return "3 Times Daily"
        case .fourTimesDaily: return "4 Times Daily"
        case .everyOtherDay: return "Every Other Day"
        case .weekly: return "Weekly"
        case .asNeeded: return "As Needed"
        }
    }

    var icon: String {
        switch self {
        case .onceDaily: return "1.circle.fill"
        case .twiceDaily: return "2.circle.fill"
        case .threeTimesDaily: return "3.circle.fill"
        case .fourTimesDaily: return "4.circle.fill"
        case .everyOtherDay: return "arrow.2.squarepath"
        case .weekly: return "calendar.circle.fill"
        case .asNeeded: return "questionmark.circle.fill"
        }
    }

    var dosesPerDay: Int {
        switch self {
        case .onceDaily: return 1
        case .twiceDaily: return 2
        case .threeTimesDaily: return 3
        case .fourTimesDaily: return 4
        case .everyOtherDay: return 1
        case .weekly: return 1
        case .asNeeded: return 0
        }
    }

    var isScheduled: Bool {
        self != .asNeeded
    }

    var defaultTimeOffsets: [Int] {
        switch self {
        case .onceDaily: return [8 * 3600]
        case .twiceDaily: return [8 * 3600, 20 * 3600]
        case .threeTimesDaily: return [8 * 3600, 14 * 3600, 20 * 3600]
        case .fourTimesDaily: return [7 * 3600, 12 * 3600, 17 * 3600, 22 * 3600]
        case .everyOtherDay: return [8 * 3600]
        case .weekly: return [8 * 3600]
        case .asNeeded: return []
        }
    }
}

// MARK: - Medication Color

enum MedicationColor: String, CaseIterable, Codable, Identifiable {
    case blue
    case green
    case orange
    case red
    case purple
    case teal
    case pink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blue: return "Blue"
        case .green: return "Green"
        case .orange: return "Orange"
        case .red: return "Red"
        case .purple: return "Purple"
        case .teal: return "Teal"
        case .pink: return "Pink"
        }
    }

    var icon: String {
        "circle.fill"
    }

    var swiftUIColor: Color {
        switch self {
        case .blue: return .blue
        case .green: return .green
        case .orange: return .orange
        case .red: return .red
        case .purple: return .purple
        case .teal: return .teal
        case .pink: return .pink
        }
    }
}

// MARK: - Dose Status

enum DoseStatus: String, CaseIterable, Codable, Identifiable {
    case upcoming
    case due
    case taken
    case skipped
    case missed

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .upcoming: return "Upcoming"
        case .due: return "Due Now"
        case .taken: return "Taken"
        case .skipped: return "Skipped"
        case .missed: return "Missed"
        }
    }

    var icon: String {
        switch self {
        case .upcoming: return "clock.fill"
        case .due: return "exclamationmark.circle.fill"
        case .taken: return "checkmark.circle.fill"
        case .skipped: return "forward.fill"
        case .missed: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .upcoming: return .secondary
        case .due: return Color.hubAccentYellow
        case .taken: return Color.hubAccentGreen
        case .skipped: return .orange
        case .missed: return Color.hubAccentRed
        }
    }

    var isResolved: Bool {
        self == .taken || self == .skipped || self == .missed
    }
}

// MARK: - Dose Log

struct DoseLog: Codable, Identifiable {
    var id: String = UUID().uuidString
    var medicationId: String
    var scheduledDate: String
    var scheduledTime: String
    var status: DoseStatus
    var actionTime: String?

    var formattedActionTime: String? {
        guard let actionTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: actionTime) else { return actionTime }
        f.timeStyle = .short
        return f.string(from: d)
    }
}

// MARK: - Dosage Suggestions

struct DosageSuggestion {
    static let commonDosages = ["5mg", "10mg", "25mg", "50mg", "100mg", "500mg"]
    static let commonSupplyAmounts = [30, 60, 90]
}