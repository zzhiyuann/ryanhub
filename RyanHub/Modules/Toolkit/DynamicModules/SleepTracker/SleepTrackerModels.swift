import Foundation

// MARK: - WakeMood Enum

enum WakeMood: String, CaseIterable, Codable, Identifiable {
    case energized
    case refreshed
    case neutral
    case groggy
    case exhausted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .energized: return "Energized"
        case .refreshed: return "Refreshed"
        case .neutral: return "Neutral"
        case .groggy: return "Groggy"
        case .exhausted: return "Exhausted"
        }
    }

    var icon: String {
        switch self {
        case .energized: return "bolt.fill"
        case .refreshed: return "sun.max.fill"
        case .neutral: return "face.smiling"
        case .groggy: return "cloud.fill"
        case .exhausted: return "battery.25percent"
        }
    }

    var color: String {
        switch self {
        case .energized: return "hubAccentYellow"
        case .refreshed: return "hubAccentGreen"
        case .neutral: return "hubTextSecondary"
        case .groggy: return "hubPrimary"
        case .exhausted: return "hubAccentRed"
        }
    }

    var sortOrder: Int {
        switch self {
        case .energized: return 0
        case .refreshed: return 1
        case .neutral: return 2
        case .groggy: return 3
        case .exhausted: return 4
        }
    }
}

// MARK: - SleepTrackerEntry

struct SleepTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var bedTime: Date
    var wakeTime: Date
    var qualityRating: Int
    var wakeMood: WakeMood
    var dreamRecall: Bool
    var notes: String

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = f.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: parsed)
    }

    var calendarDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var dayOfWeek: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = f.date(from: date) else { return "" }
        let day = DateFormatter()
        day.dateFormat = "EEE"
        return day.string(from: parsed)
    }

    var isWeekend: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = f.date(from: date) else { return false }
        let weekday = Calendar.current.component(.weekday, from: parsed)
        return weekday == 1 || weekday == 7
    }

    var summaryLine: String {
        let hrs = sleepDuration
        let hrsInt = Int(hrs)
        let mins = Int((hrs - Double(hrsInt)) * 60)
        return "\(hrsInt)h \(mins)m · \(qualityStars) · \(wakeMood.displayName)"
    }

    var sleepDuration: Double {
        let interval = wakeTime.timeIntervalSince(bedTime)
        let hours: Double
        if interval > 0 {
            hours = interval / 3600.0
        } else {
            // Overnight: bedTime is after wakeTime means crossing midnight
            hours = (interval + 86400.0) / 3600.0
        }
        return hours
    }

    var sleepDurationFormatted: String {
        let hrs = sleepDuration
        let hrsInt = Int(hrs)
        let mins = Int((hrs - Double(hrsInt)) * 60)
        if mins == 0 {
            return "\(hrsInt)h"
        }
        return "\(hrsInt)h \(mins)m"
    }

    var qualityStars: String {
        let clamped = max(1, min(5, qualityRating))
        return String(repeating: "★", count: clamped) + String(repeating: "☆", count: 5 - clamped)
    }

    var formattedBedTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: bedTime)
    }

    var formattedWakeTime: String {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: wakeTime)
    }

    /// Minutes from midnight for bedTime, handling pre/post midnight.
    /// Pre-midnight times (e.g., 10pm) return negative values (e.g., -120).
    /// Post-midnight times (e.g., 1am) return positive values (e.g., 60).
    var bedTimeMinutesFromMidnight: Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: bedTime)
        let minute = cal.component(.minute, from: bedTime)
        let totalMinutes = Double(hour * 60 + minute)
        // If hour >= 12, treat as before midnight (negative offset)
        if hour >= 12 {
            return totalMinutes - 1440.0
        }
        return totalMinutes
    }

    // MARK: - Factory

    static func create(
        bedTime: Date,
        wakeTime: Date,
        qualityRating: Int = 3,
        wakeMood: WakeMood = .neutral,
        dreamRecall: Bool = false,
        notes: String = ""
    ) -> SleepTrackerEntry {
        SleepTrackerEntry(
            bedTime: bedTime,
            wakeTime: wakeTime,
            qualityRating: max(1, min(5, qualityRating)),
            wakeMood: wakeMood,
            dreamRecall: dreamRecall,
            notes: notes
        )
    }
}

// MARK: - DurationBucket

enum DurationBucket: String, CaseIterable, Identifiable {
    case under6 = "<6h"
    case sixToSeven = "6-7h"
    case sevenToEight = "7-8h"
    case eightToNine = "8-9h"
    case over9 = "9h+"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var range: ClosedRange<Double> {
        switch self {
        case .under6: return 0...5.99
        case .sixToSeven: return 6.0...6.99
        case .sevenToEight: return 7.0...7.99
        case .eightToNine: return 8.0...8.99
        case .over9: return 9.0...24.0
        }
    }

    static func bucket(for duration: Double) -> DurationBucket {
        switch duration {
        case ..<6.0: return .under6
        case 6.0..<7.0: return .sixToSeven
        case 7.0..<8.0: return .sevenToEight
        case 8.0..<9.0: return .eightToNine
        default: return .over9
        }
    }
}

// MARK: - WeekDayEntry (for timeline chart)

struct WeekDayEntry: Identifiable {
    let id = UUID().uuidString
    let date: Date
    let dayLabel: String
    let entry: SleepTrackerEntry?

    var hasEntry: Bool { entry != nil }
}

// MARK: - SleepScoreGrade

enum SleepScoreGrade {
    case excellent
    case good
    case fair
    case poor

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    var colorName: String {
        switch self {
        case .excellent: return "hubAccentGreen"
        case .good: return "hubPrimaryLight"
        case .fair: return "hubAccentYellow"
        case .poor: return "hubAccentRed"
        }
    }

    static func from(score: Int) -> SleepScoreGrade {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }
}

// MARK: - ConsistencyGrade

enum ConsistencyGrade {
    case excellent
    case good
    case fair
    case poor

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    static func from(score: Int) -> ConsistencyGrade {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }
}

// MARK: - SleepDebtLevel

enum SleepDebtLevel {
    case healthy
    case mild
    case moderate
    case severe

    var label: String {
        switch self {
        case .healthy: return "Healthy"
        case .mild: return "Mild"
        case .moderate: return "Moderate"
        case .severe: return "Severe"
        }
    }

    var colorName: String {
        switch self {
        case .healthy: return "hubAccentGreen"
        case .mild: return "hubAccentYellow"
        case .moderate: return "hubPrimaryLight"
        case .severe: return "hubAccentRed"
        }
    }

    static func from(debtHours: Double) -> SleepDebtLevel {
        switch debtHours {
        case ..<2.0: return .healthy
        case 2.0..<5.0: return .mild
        case 5.0..<8.0: return .moderate
        default: return .severe
        }
    }
}