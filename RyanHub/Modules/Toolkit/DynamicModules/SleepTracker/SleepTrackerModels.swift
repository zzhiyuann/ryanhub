import Foundation

// MARK: - Entry

struct SleepTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var bedtime: Date = Date()
    var wakeTime: Date = Date()
    var sleepHours: Double = 7.0
    var qualityRating: Int = 3
    var wakeUpMood: WakeUpMood = .neutral
    var sleepFactor: SleepFactor = .none
    var hadDreams: Bool = false
    var notes: String = ""

    // MARK: Computed

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        guard let d = Self.dateFormatter.date(from: date) else { return date }
        return f.string(from: d)
    }

    var summaryLine: String {
        let hrs = String(format: "%.1f", sleepHours)
        return "\(hrs)h · Quality \(qualityRating)/5 · \(wakeUpMood.displayName)"
    }

    var formattedBedtime: String {
        Self.timeFormatter.string(from: bedtime)
    }

    var formattedWakeTime: String {
        Self.timeFormatter.string(from: wakeTime)
    }

    /// Ratio of actual time in bed to logged sleepHours (0.0–1.0+).
    var sleepEfficiency: Double? {
        let inBed = wakeTime.timeIntervalSince(bedtime) / 3600.0
        guard inBed > 0 else { return nil }
        return min(sleepHours / inBed, 1.0)
    }

    /// Formatted efficiency percentage string, or nil if times are invalid.
    var formattedEfficiency: String? {
        guard let e = sleepEfficiency else { return nil }
        return "\(Int(e * 100))%"
    }

    /// Whether this entry meets the streak criteria (hours >= goal AND quality >= 3).
    func meetsStreakCriteria(goal: Double) -> Bool {
        sleepHours >= goal && qualityRating >= 3
    }

    /// Sleep deficit against a given goal (0 if goal met).
    func deficit(goal: Double) -> Double {
        max(0, goal - sleepHours)
    }

    /// Calendar date parsed from the stored `date` string, used for grouping.
    var calendarDate: Date? {
        Self.dateFormatter.date(from: date)
    }

    /// Weekday name (e.g. "Saturday") derived from the entry date.
    var weekdayName: String {
        guard let d = calendarDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    // MARK: Shared formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()
}

// MARK: - WakeUpMood

enum WakeUpMood: String, CaseIterable, Codable, Identifiable {
    case energized
    case refreshed
    case neutral
    case groggy
    case exhausted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .energized:  return "Energized"
        case .refreshed:  return "Refreshed"
        case .neutral:    return "Neutral"
        case .groggy:     return "Groggy"
        case .exhausted:  return "Exhausted"
        }
    }

    var icon: String {
        switch self {
        case .energized:  return "sun.max.fill"
        case .refreshed:  return "leaf.fill"
        case .neutral:    return "face.smiling"
        case .groggy:     return "cloud.fill"
        case .exhausted:  return "moon.fill"
        }
    }

    /// Positive moods that signal a good night's rest.
    var isPositive: Bool {
        switch self {
        case .energized, .refreshed: return true
        case .neutral, .groggy, .exhausted: return false
        }
    }

    /// Numeric score (1–5) used for aggregate mood calculations.
    var score: Int {
        switch self {
        case .energized:  return 5
        case .refreshed:  return 4
        case .neutral:    return 3
        case .groggy:     return 2
        case .exhausted:  return 1
        }
    }
}

// MARK: - SleepFactor

enum SleepFactor: String, CaseIterable, Codable, Identifiable {
    case none
    case caffeine
    case exercise
    case screenTime
    case stress
    case alcohol
    case lateMeal
    case noise

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:        return "None"
        case .caffeine:    return "Caffeine"
        case .exercise:    return "Exercise"
        case .screenTime:  return "Screen Time"
        case .stress:      return "Stress"
        case .alcohol:     return "Alcohol"
        case .lateMeal:    return "Late Meal"
        case .noise:       return "Noise"
        }
    }

    var icon: String {
        switch self {
        case .none:        return "minus.circle"
        case .caffeine:    return "cup.and.saucer.fill"
        case .exercise:    return "figure.run"
        case .screenTime:  return "iphone"
        case .stress:      return "brain.head.profile"
        case .alcohol:     return "wineglass.fill"
        case .lateMeal:    return "fork.knife"
        case .noise:       return "speaker.wave.3.fill"
        }
    }

    /// Whether this factor is generally considered sleep-negative vs sleep-positive.
    var isNegative: Bool {
        switch self {
        case .none: return false
        case .exercise: return false
        default: return true
        }
    }
}

// MARK: - Domain constants

enum SleepTrackerConstants {
    static let defaultDailyGoal: Double = 8.0
    static let streakMinQuality: Int = 3
    static let consistencyStdDevThreshold: Double = 45.0   // minutes
    static let consistencyWindowDays: Int = 14
    static let insightWindowDays: Int = 7
    static let moodWindowDays: Int = 30
    static let trendWindowDays: Int = 30
    static let sleepDebtWindowDays: Int = 7
}