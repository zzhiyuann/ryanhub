import Foundation

// MARK: - Enums

enum WakeUpMood: String, CaseIterable, Codable, Identifiable {
    case energized
    case rested
    case neutral
    case groggy
    case exhausted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .energized: return "Energized"
        case .rested:    return "Rested"
        case .neutral:   return "Neutral"
        case .groggy:    return "Groggy"
        case .exhausted: return "Exhausted"
        }
    }

    var icon: String {
        switch self {
        case .energized: return "bolt.fill"
        case .rested:    return "sun.max.fill"
        case .neutral:   return "minus.circle.fill"
        case .groggy:    return "cloud.fill"
        case .exhausted: return "battery.0percent"
        }
    }

    /// Normalized 0–1 weight used in composite scoring and correlation analysis.
    var qualityWeight: Double {
        switch self {
        case .energized: return 1.0
        case .rested:    return 0.8
        case .neutral:   return 0.5
        case .groggy:    return 0.3
        case .exhausted: return 0.0
        }
    }
}

enum SleepDisruptor: String, CaseIterable, Codable, Identifiable {
    case none
    case stress
    case caffeine
    case screenTime
    case noise
    case temperature
    case pain
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:        return "None"
        case .stress:      return "Stress"
        case .caffeine:    return "Caffeine"
        case .screenTime:  return "Screen Time"
        case .noise:       return "Noise"
        case .temperature: return "Temperature"
        case .pain:        return "Pain/Discomfort"
        case .other:       return "Other"
        }
    }

    var icon: String {
        switch self {
        case .none:        return "checkmark.circle.fill"
        case .stress:      return "brain.head.profile"
        case .caffeine:    return "cup.and.saucer.fill"
        case .screenTime:  return "iphone"
        case .noise:       return "speaker.wave.3.fill"
        case .temperature: return "thermometer.medium"
        case .pain:        return "cross.case.fill"
        case .other:       return "ellipsis.circle.fill"
        }
    }

    /// True for any disruptor that meaningfully affects sleep (excludes .none).
    var isActive: Bool { self != .none }
}

// MARK: - Entry Model

struct SleepTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    // MARK: Data fields
    var bedtime: Date = Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: Date()) ?? Date()
    var wakeTime: Date = Calendar.current.date(bySettingHour: 6, minute: 0, second: 0, of: Date()) ?? Date()
    var qualityRating: Int = 3
    var wakeUpMood: WakeUpMood = .neutral
    var sleepDisruptor: SleepDisruptor = .none
    var dreamRecall: Bool = false
    var notes: String = ""

    // MARK: - Duration

    /// Total sleep duration in hours, handling cross-midnight arithmetic.
    var durationHours: Double {
        let interval = wakeTime.timeIntervalSince(bedtime)
        let adjusted = interval < 0 ? interval + 86_400 : interval
        return adjusted / 3_600
    }

    var durationMinutes: Int { Int(durationHours * 60) }

    var formattedDuration: String {
        let hours = Int(durationHours)
        let minutes = Int((durationHours - Double(hours)) * 60)
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    // MARK: - Formatted Timestamps

    var formattedDate: String {
        let parseFormatter = DateFormatter()
        parseFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = parseFormatter.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: parsed)
    }

    var formattedBedtime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: bedtime)
    }

    var formattedWakeTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: wakeTime)
    }

    var timeRangeLabel: String { "\(formattedBedtime) – \(formattedWakeTime)" }

    // MARK: - Summary

    var summaryLine: String {
        "\(formattedDuration) · Quality \(qualityRating)/5 · \(wakeUpMood.displayName)"
    }

    var qualityStars: String {
        String(repeating: "★", count: qualityRating) +
        String(repeating: "☆", count: SleepTrackerConstants.maxQualityRating - qualityRating)
    }

    // MARK: - Goal & Streak Support

    /// Whether this entry's duration meets or exceeds the daily goal.
    var meetsGoal: Bool { durationHours >= SleepTrackerConstants.defaultDailyGoal }

    // MARK: - Bedtime Consistency Support

    /// Bedtime expressed as a decimal hour normalized so post-midnight times
    /// (0–6 h) map to 24–30 h, enabling correct chronological sorting.
    var normalizedBedtimeHour: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        let h = Double(comps.hour ?? 0)
        let m = Double(comps.minute ?? 0) / 60.0
        return (h < 6 ? h + 24 : h) + m
    }

    // MARK: - Calendar / Day-of-Week Support

    /// The calendar date represented by the `date` string.
    var calendarDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var dayOfWeekAbbreviation: String {
        guard let d = calendarDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }

    var isWeekend: Bool {
        guard let d = calendarDate else { return false }
        let weekday = Calendar.current.component(.weekday, from: d)
        return weekday == 1 || weekday == 7
    }

    // MARK: - Heatmap

    /// Normalized 0–1 intensity for calendar heatmap coloring (based on quality).
    var heatmapIntensity: Double {
        Double(qualityRating) / Double(SleepTrackerConstants.maxQualityRating)
    }
}

// MARK: - Module Constants

enum SleepTrackerConstants {
    static let defaultDailyGoal: Double    = 8.0
    static let minQualityRating: Int       = 1
    static let maxQualityRating: Int       = 5
    static let optimalMinHours: Double     = 7.0
    static let optimalMaxHours: Double     = 9.0

    // Bedtime consistency thresholds (minutes of standard deviation)
    static let consistencyPerfectSD: Double = 15.0
    static let consistencyWorstSD: Double   = 90.0

    // Trend comparison thresholds
    static let trendQualityThreshold: Double   = 0.3
    static let trendDurationThreshold: Double  = 0.25

    // Lookback windows
    static let weeklyWindow: Int           = 7
    static let consistencyWindow: Int      = 14
    static let insightLookback: Int        = 30
}