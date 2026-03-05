import Foundation

// MARK: - Enums

enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case mindfulness
    case fitness
    case learning
    case creativity
    case health
    case productivity
    case social
    case selfCare

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mindfulness: return "Mindfulness"
        case .fitness: return "Fitness"
        case .learning: return "Learning"
        case .creativity: return "Creativity"
        case .health: return "Health"
        case .productivity: return "Productivity"
        case .social: return "Social"
        case .selfCare: return "Self Care"
        }
    }

    var icon: String {
        switch self {
        case .mindfulness: return "brain.head.profile"
        case .fitness: return "figure.run"
        case .learning: return "book.fill"
        case .creativity: return "paintbrush.fill"
        case .health: return "heart.fill"
        case .productivity: return "bolt.fill"
        case .social: return "person.2.fill"
        case .selfCare: return "sparkles"
        }
    }
}

enum TimeOfDay: String, CaseIterable, Codable, Identifiable {
    case morning
    case afternoon
    case evening
    case night

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

// MARK: - Entry Model

struct HabitTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var habitName: String = ""
    var category: HabitCategory = .mindfulness
    var completed: Bool = false
    var duration: Int = 0
    var quality: Int = 3
    var timeOfDay: TimeOfDay = .morning
    var notes: String = ""

    // MARK: - Computed: Formatting

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
        String(date.prefix(10))
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var summaryLine: String {
        var parts: [String] = [habitName.isEmpty ? "Unnamed Habit" : habitName]
        if completed { parts.append("✓") }
        if duration > 0 { parts.append("\(duration) min") }
        parts.append(category.displayName)
        return parts.joined(separator: " · ")
    }

    // MARK: - Computed: Domain

    var qualityLabel: String {
        switch quality {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "—"
        }
    }

    var qualityColor: String {
        switch quality {
        case 1, 2: return "hubAccentRed"
        case 3: return "hubAccentYellow"
        case 4, 5: return "hubAccentGreen"
        default: return "textSecondary"
        }
    }

    var durationLabel: String {
        duration == 0 ? "—" : "\(duration) min"
    }

    var hasReflection: Bool {
        !notes.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Streak Milestone

struct StreakMilestone {
    let days: Int
    let message: String

    static let all: [StreakMilestone] = [
        StreakMilestone(days: 7,   message: "One week strong! You're building momentum."),
        StreakMilestone(days: 14,  message: "Two weeks! Habits are starting to stick."),
        StreakMilestone(days: 21,  message: "21 days — science says this is where habits form."),
        StreakMilestone(days: 30,  message: "30-day streak! You're unstoppable."),
        StreakMilestone(days: 50,  message: "50 days of consistency. Remarkable."),
        StreakMilestone(days: 100, message: "100-day streak! You've made this a lifestyle."),
        StreakMilestone(days: 365, message: "365 days. A full year. Legendary."),
    ]

    static func message(for streak: Int) -> String? {
        all.first(where: { $0.days == streak })?.message
    }
}

// MARK: - Habit Summary (per named habit)

struct HabitSummary: Identifiable {
    let id: String
    let habitName: String
    let category: HabitCategory
    let currentStreak: Int
    let completionRate30d: Double
    let totalCompletions: Int
    let averageQuality: Double
    let lastCompletedDate: String?

    var isAtRisk: Bool { completionRate30d < 0.5 && totalCompletions > 3 }
}

// MARK: - Heatmap Cell

struct HeatmapCell: Identifiable {
    let id: String
    let date: Date
    let count: Int

    var intensity: Double {
        switch count {
        case 0: return 0.0
        case 1: return 0.25
        case 2: return 0.5
        case 3: return 0.75
        default: return 1.0
        }
    }
}

// MARK: - Daily Habit State (for dashboard checklist)

struct DailyHabitState: Identifiable {
    let id: String
    let habitName: String
    let category: HabitCategory
    var isCompletedToday: Bool
    let currentStreak: Int

    var streakAtRisk: Bool { !isCompletedToday && currentStreak > 0 }
}

// MARK: - Constants

enum HabitTrackerConstants {
    static let defaultDailyGoal: Int = 5
    static let qualityRange: ClosedRange<Double> = 1...5
    static let durationStep: Int = 5
    static let heatmapWeeks: Int = 12
    static let streakRiskHour: Int = 18
    static let trendWindowDays: Int = 7
    static let consistencyWindowDays: Int = 30
    static let newHabitThresholdDays: Int = 14
    static let categoryDominanceThreshold: Double = 0.80
    static let risingTrendThreshold: Double = 0.05
}