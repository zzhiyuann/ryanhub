import Foundation

// MARK: - Entry

struct DailyAffirmationsEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var affirmationText: String = ""
    var category: AffirmationCategory = .selfWorth
    var moodBefore: Int = 5
    var moodAfter: Int = 5
    var practiceMinutes: Int = 5
    var isFavorite: Bool = false
    var reflectionNote: String = ""

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

    var moodLift: Int {
        moodAfter - moodBefore
    }

    var moodLiftDescription: String {
        switch moodLift {
        case ..<0:     return "Decreased"
        case 0:        return "Neutral"
        case 1...2:    return "Slightly Better"
        case 3...4:    return "Better"
        default:       return "Much Better"
        }
    }

    var summaryLine: String {
        let lift = moodLift >= 0 ? "+\(moodLift)" : "\(moodLift)"
        return "\(category.displayName) · \(practiceMinutes) min · Mood \(lift)"
    }

    var durationLabel: String {
        practiceMinutes == 1 ? "1 min" : "\(practiceMinutes) min"
    }

    var hasReflection: Bool {
        !reflectionNote.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - AffirmationCategory

enum AffirmationCategory: String, CaseIterable, Codable, Identifiable {
    case selfWorth
    case career
    case health
    case relationships
    case abundance
    case gratitude
    case resilience
    case creativity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .selfWorth:     return "Self-Worth"
        case .career:        return "Career & Purpose"
        case .health:        return "Health & Body"
        case .relationships: return "Relationships"
        case .abundance:     return "Abundance"
        case .gratitude:     return "Gratitude"
        case .resilience:    return "Resilience"
        case .creativity:    return "Creativity"
        }
    }

    var icon: String {
        switch self {
        case .selfWorth:     return "heart.fill"
        case .career:        return "briefcase.fill"
        case .health:        return "figure.mind.and.body"
        case .relationships: return "person.2.fill"
        case .abundance:     return "sparkles"
        case .gratitude:     return "hands.clap.fill"
        case .resilience:    return "shield.fill"
        case .creativity:    return "paintbrush.fill"
        }
    }
}

// MARK: - Streak Milestone

struct AffirmationStreakMilestone: Equatable {
    let days: Int
    let message: String

    static let milestones: [AffirmationStreakMilestone] = [
        AffirmationStreakMilestone(days: 7,   message: "One full week of affirmations — you're building momentum!"),
        AffirmationStreakMilestone(days: 14,  message: "Two weeks strong! Your mindset is shifting."),
        AffirmationStreakMilestone(days: 30,  message: "30 days! This is becoming a true habit."),
        AffirmationStreakMilestone(days: 60,  message: "60 days — your neural pathways are reshaping."),
        AffirmationStreakMilestone(days: 100, message: "100-day streak! You are unstoppable."),
        AffirmationStreakMilestone(days: 365, message: "One full year of daily affirmations. Incredible!")
    ]

    static func milestone(for streak: Int) -> AffirmationStreakMilestone? {
        milestones.first { $0.days == streak }
    }
}

// MARK: - Helpers

extension [DailyAffirmationsEntry] {
    func forDate(_ dateString: String) -> [DailyAffirmationsEntry] {
        filter { $0.dateOnly == dateString }
    }

    func filtered(by category: AffirmationCategory) -> [DailyAffirmationsEntry] {
        filter { $0.category == category }
    }

    var averageMoodLift: Double {
        guard !isEmpty else { return 0 }
        let total = reduce(0) { $0 + $1.moodLift }
        return Double(total) / Double(count)
    }

    var totalPracticeMinutes: Int {
        reduce(0) { $0 + $1.practiceMinutes }
    }

    var categoryDistribution: [(AffirmationCategory, Int)] {
        var counts: [AffirmationCategory: Int] = [:]
        forEach { counts[$0.category, default: 0] += 1 }
        return AffirmationCategory.allCases
            .compactMap { cat in
                let count = counts[cat] ?? 0
                return count > 0 ? (cat, count) : nil
            }
            .sorted { $0.1 > $1.1 }
    }

    var dominantCategory: AffirmationCategory? {
        categoryDistribution.first?.0
    }

    /// Returns true if this collection represents a day where any entry was logged.
    var hasAnyEntry: Bool { !isEmpty }
}