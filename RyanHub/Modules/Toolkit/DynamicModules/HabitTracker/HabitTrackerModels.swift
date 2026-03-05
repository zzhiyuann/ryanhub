import Foundation

// MARK: - Main Entry

struct HabitTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var habitName: String = ""
    var category: HabitCategory = .health
    var completed: Bool = false
    var durationMinutes: Int = 0
    var satisfaction: Int = 3
    var timeOfDay: TimeOfDay = .anytime
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
        String(date.prefix(10))
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var summaryLine: String {
        var parts: [String] = [habitName.isEmpty ? "Habit" : habitName]
        if completed {
            parts.append("✓")
        }
        if durationMinutes > 0 {
            parts.append("\(durationMinutes)m")
        }
        if satisfaction > 0 {
            parts.append(String(repeating: "★", count: satisfaction))
        }
        return parts.joined(separator: " · ")
    }

    var satisfactionLabel: String {
        switch satisfaction {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Great"
        case 5: return "Excellent"
        default: return "—"
        }
    }

    var durationFormatted: String {
        guard durationMinutes > 0 else { return "—" }
        if durationMinutes < 60 {
            return "\(durationMinutes) min"
        }
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - HabitCategory

enum HabitCategory: String, CaseIterable, Codable, Identifiable {
    case mindfulness
    case health
    case productivity
    case learning
    case creative
    case selfCare
    case social

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mindfulness:  return "Mindfulness"
        case .health:       return "Health & Fitness"
        case .productivity: return "Productivity"
        case .learning:     return "Learning"
        case .creative:     return "Creative"
        case .selfCare:     return "Self-Care"
        case .social:       return "Social"
        }
    }

    var icon: String {
        switch self {
        case .mindfulness:  return "brain.head.profile"
        case .health:       return "heart.fill"
        case .productivity: return "bolt.fill"
        case .learning:     return "book.fill"
        case .creative:     return "paintpalette.fill"
        case .selfCare:     return "sparkles"
        case .social:       return "person.2.fill"
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
        case .morning:   return "Morning"
        case .afternoon: return "Afternoon"
        case .evening:   return "Evening"
        case .anytime:   return "Anytime"
        }
    }

    var icon: String {
        switch self {
        case .morning:   return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening:   return "sunset.fill"
        case .anytime:   return "clock.fill"
        }
    }
}

// MARK: - Per-Habit Streak Summary

struct HabitStreakSummary: Identifiable {
    var id: String { habitName }
    let habitName: String
    let currentStreak: Int
    let bestStreak: Int

    var streakLabel: String {
        currentStreak == 1 ? "1 day" : "\(currentStreak) days"
    }

    var isPersonalBest: Bool {
        currentStreak > 0 && currentStreak == bestStreak
    }
}

// MARK: - Daily Habit Completion Record (internal aggregation helper)

struct DailyHabitSummary: Identifiable {
    var id: String { dateString }
    let dateString: String          // "yyyy-MM-dd"
    let totalHabits: Int
    let completedHabits: Int

    var completionRate: Double {
        guard totalHabits > 0 else { return 0 }
        return Double(completedHabits) / Double(totalHabits)
    }

    var isFullCompletion: Bool { completedHabits == totalHabits && totalHabits > 0 }
}

// MARK: - Heatmap Cell

struct HeatmapDay: Identifiable {
    var id: String { dateString }
    let dateString: String
    let date: Date
    let intensity: Double           // 0.0 – 1.0 (completion rate)

    var intensityLevel: Int {
        switch intensity {
        case 0:         return 0
        case 0..<0.25:  return 1
        case 0.25..<0.5: return 2
        case 0.5..<0.75: return 3
        default:        return 4
        }
    }
}

// MARK: - Category Analytics Row

struct HabitCategoryBreakdown: Identifiable {
    var id: String { categoryName }
    let categoryName: String
    let category: HabitCategory
    let count: Int
    let completionRate: Double

    var completionPercent: String {
        String(format: "%.0f%%", completionRate)
    }
}

// MARK: - Day-of-Week Completion Row

struct DayOfWeekStat: Identifiable {
    var id: String { day }
    let day: String                 // "Mon", "Tue", …
    let rate: Double                // 0.0 – 1.0

    var displayRate: String {
        String(format: "%.0f%%", rate * 100)
    }
}

// MARK: - Date Helpers

extension String {
    /// Parses a "yyyy-MM-dd" date-only string into a Date.
    var asCalendarDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: self)
    }
}

extension Date {
    /// "yyyy-MM-dd" string for the receiver.
    var dateOnlyString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.string(from: self)
    }

    /// Short weekday abbreviation: "Mon", "Tue", …
    var shortWeekdayName: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: self)
    }

    /// Calendar day-of-week index (1 = Sun … 7 = Sat).
    var weekdayIndex: Int {
        Calendar.current.component(.weekday, from: self)
    }

    /// Start of day (midnight) for the receiver.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Returns a Date exactly `n` calendar days before the receiver's start of day.
    func daysAgo(_ n: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -n, to: startOfDay) ?? self
    }
}