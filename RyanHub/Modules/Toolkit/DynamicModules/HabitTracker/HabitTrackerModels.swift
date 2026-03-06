import Foundation

// MARK: - HabitCategory

enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case health
    case mindfulness
    case productivity
    case fitness
    case learning
    case selfCare
    case social
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .health: return "Health"
        case .mindfulness: return "Mindfulness"
        case .productivity: return "Productivity"
        case .fitness: return "Fitness"
        case .learning: return "Learning"
        case .selfCare: return "Self Care"
        case .social: return "Social"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .health: return "heart.fill"
        case .mindfulness: return "brain.head.profile"
        case .productivity: return "bolt.fill"
        case .fitness: return "figure.run"
        case .learning: return "book.fill"
        case .selfCare: return "sparkles"
        case .social: return "person.2.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

// MARK: - TimeOfDay

enum TimeOfDay: String, CaseIterable, Codable, Identifiable {
    case morning
    case afternoon
    case evening
    case anytime

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .anytime: return "Anytime"
        }
    }

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .anytime: return "clock.fill"
        }
    }

    /// Sort ordinal for grouping habits by time of day
    var sortOrder: Int {
        switch self {
        case .morning: return 0
        case .afternoon: return 1
        case .evening: return 2
        case .anytime: return 3
        }
    }
}

// MARK: - MilestoneTier

enum MilestoneTier: Int, CaseIterable, Comparable {
    case bronze = 7
    case silver = 30
    case gold = 60
    case platinum = 100

    var label: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold: return "Gold"
        case .platinum: return "Platinum"
        }
    }

    var icon: String {
        switch self {
        case .bronze: return "medal.fill"
        case .silver: return "medal.fill"
        case .gold: return "trophy.fill"
        case .platinum: return "crown.fill"
        }
    }

    static func < (lhs: MilestoneTier, rhs: MilestoneTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Returns the highest milestone tier achieved for a given streak count, or nil
    static func tier(for streakDays: Int) -> MilestoneTier? {
        Self.allCases.reversed().first { streakDays >= $0.rawValue }
    }

    /// All milestone thresholds as day counts
    static let thresholds: [Int] = allCases.map(\.rawValue)
}

// MARK: - HabitTrackerEntry

struct HabitTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var name: String = ""
    var habitIcon: String = "checkmark.circle.fill"
    var category: HabitCategory = .other
    var timeOfDay: TimeOfDay = .anytime
    var targetDaysPerWeek: Int = 7
    var isArchived: Bool = false

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: d)
    }

    var summaryLine: String {
        let freq = targetDaysPerWeek == 7 ? "Daily" : "\(targetDaysPerWeek) days/week"
        return "\(name) · \(freq) · \(timeOfDay.displayName)"
    }

    var isDaily: Bool {
        targetDaysPerWeek == 7
    }

    var frequencyLabel: String {
        if targetDaysPerWeek == 7 {
            return "Daily"
        }
        return "\(targetDaysPerWeek) days/week"
    }

    var creationDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }
}

// MARK: - HabitCompletion

/// Records a single completion event for a habit on a specific date
struct HabitCompletion: Codable, Identifiable {
    var id: String = UUID().uuidString
    var habitId: String
    var dateString: String // "yyyy-MM-dd" format

    /// Creates a completion for today
    static func today(habitId: String) -> HabitCompletion {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return HabitCompletion(habitId: habitId, dateString: f.string(from: Date()))
    }
}

// MARK: - HabitMilestone

/// Represents an achieved streak milestone for a specific habit
struct HabitMilestone: Codable, Identifiable {
    var id: String = UUID().uuidString
    var habitId: String
    var habitName: String
    var days: Int
    var dateAchieved: Date

    var tier: MilestoneTier? {
        MilestoneTier.tier(for: days)
    }
}

// MARK: - HabitStreakInfo

/// Aggregated streak information for a single habit, used by views
struct HabitStreakInfo {
    let habitId: String
    let currentStreak: Int
    let bestStreak: Int
    let trailingWeek: [Bool] // 7 elements, index 0 = 6 days ago, index 6 = today

    var tier: MilestoneTier? {
        MilestoneTier.tier(for: currentStreak)
    }

    var hasActiveStreak: Bool {
        currentStreak > 0
    }

    var hasGoldenGlow: Bool {
        currentStreak > 7
    }
}

// MARK: - HeatmapDay

/// Represents a single day cell in the contribution heatmap
struct HeatmapDay: Identifiable {
    let id = UUID().uuidString
    let date: Date
    let dateString: String // "yyyy-MM-dd"
    let completionRate: Double // 0.0 to 1.0
    let completedHabits: [String] // habit names completed that day
    let totalHabits: Int
}

// MARK: - Helpers

extension HabitTrackerEntry {
    /// Curated SF Symbols for habit icon picker
    static let curatedIcons: [String] = [
        "figure.mind.and.body", "book.fill", "drop.fill", "dumbbell.fill",
        "pencil.and.outline", "bed.double.fill", "leaf.fill", "heart.fill",
        "brain.head.profile", "sun.max.fill", "moon.fill", "cup.and.saucer.fill",
        "figure.run", "figure.walk", "music.note", "paintbrush.fill",
        "fork.knife", "pills.fill", "cross.fill", "phone.down.fill",
        "face.smiling.inverse", "hands.clap.fill", "text.book.closed.fill", "graduationcap.fill"
    ]
}

extension Date {
    /// Returns "yyyy-MM-dd" string for the date
    var habitDateString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: self)
    }
}