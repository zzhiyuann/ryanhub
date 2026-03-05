import Foundation

// MARK: - MoodActivity

enum MoodActivity: String, CaseIterable, Codable, Identifiable {
    case exercise
    case work
    case socializing
    case rest
    case creative
    case outdoors
    case reading
    case meditation
    case cooking
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .exercise:   return "Exercise"
        case .work:       return "Work"
        case .socializing:return "Socializing"
        case .rest:       return "Rest"
        case .creative:   return "Creative"
        case .outdoors:   return "Outdoors"
        case .reading:    return "Reading"
        case .meditation: return "Meditation"
        case .cooking:    return "Cooking"
        case .other:      return "Other"
        }
    }

    var icon: String {
        switch self {
        case .exercise:   return "figure.run"
        case .work:       return "briefcase.fill"
        case .socializing:return "person.2.fill"
        case .rest:       return "bed.double.fill"
        case .creative:   return "paintbrush.fill"
        case .outdoors:   return "leaf.fill"
        case .reading:    return "book.fill"
        case .meditation: return "brain.head.profile"
        case .cooking:    return "fork.knife"
        case .other:      return "ellipsis.circle.fill"
        }
    }
}

// MARK: - SocialContext

enum SocialContext: String, CaseIterable, Codable, Identifiable {
    case alone
    case partner
    case family
    case friends
    case coworkers
    case publicCrowd

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alone:       return "Alone"
        case .partner:     return "Partner"
        case .family:      return "Family"
        case .friends:     return "Friends"
        case .coworkers:   return "Coworkers"
        case .publicCrowd: return "Public"
        }
    }

    var icon: String {
        switch self {
        case .alone:       return "person.fill"
        case .partner:     return "heart.fill"
        case .family:      return "house.fill"
        case .friends:     return "person.3.fill"
        case .coworkers:   return "person.2.badge.gearshape"
        case .publicCrowd: return "person.2.wave.2.fill"
        }
    }
}

// MARK: - TrendDirection

enum TrendDirection {
    case up
    case down
    case stable

    var icon: String {
        switch self {
        case .up:     return "arrow.up.right"
        case .down:   return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }

    var label: String {
        switch self {
        case .up:     return "Improving"
        case .down:   return "Declining"
        case .stable: return "Stable"
        }
    }
}

// MARK: - MoodInsight

struct MoodInsight: Identifiable {
    let id: String
    let title: String
    let body: String
    let icon: String
    let isAlert: Bool

    init(title: String, body: String, icon: String, isAlert: Bool = false) {
        self.id = UUID().uuidString
        self.title = title
        self.body = body
        self.icon = icon
        self.isAlert = isAlert
    }
}

// MARK: - MoodJournalEntry

struct MoodJournalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    // Data fields
    var moodRating: Int = 5
    var energyLevel: Int = 5
    var anxietyLevel: Int = 5
    var activity: MoodActivity = .other
    var socialContext: SocialContext = .alone
    var notes: String = ""

    // MARK: - Date Helpers

    var calendarDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    /// "yyyy-MM-dd" prefix used as dictionary key for day grouping
    var dayKey: String { String(date.prefix(10)) }

    var formattedDate: String {
        guard let d = calendarDate else { return date }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: d)
    }

    var formattedTime: String {
        guard let d = calendarDate else { return "" }
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: d)
    }

    // MARK: - Mood Representation

    var moodEmoji: String {
        switch moodRating {
        case 1:  return "😞"
        case 2:  return "😟"
        case 3:  return "😕"
        case 4:  return "😐"
        case 5:  return "🙂"
        case 6:  return "😊"
        case 7:  return "😄"
        case 8:  return "😁"
        case 9:  return "🤩"
        case 10: return "🥳"
        default: return "🙂"
        }
    }

    var moodLabel: String {
        switch moodRating {
        case 1...2:  return "Very Low"
        case 3...4:  return "Low"
        case 5...6:  return "Neutral"
        case 7...8:  return "Good"
        case 9...10: return "Excellent"
        default:     return "Neutral"
        }
    }

    /// Returns "hubAccentRed", "hubAccentYellow", or "hubAccentGreen" for use with named colors
    var moodColorName: String {
        switch moodRating {
        case 1...3:  return "hubAccentRed"
        case 4...6:  return "hubAccentYellow"
        case 7...10: return "hubAccentGreen"
        default:     return "hubAccentYellow"
        }
    }

    // MARK: - Energy / Anxiety Labels

    var energyLabel: String {
        switch energyLevel {
        case 1...3:  return "Drained"
        case 4...6:  return "Moderate"
        case 7...10: return "Energized"
        default:     return "Moderate"
        }
    }

    var anxietyLabel: String {
        switch anxietyLevel {
        case 1...3:  return "Calm"
        case 4...6:  return "Mild"
        case 7...10: return "High"
        default:     return "Mild"
        }
    }

    // MARK: - Summary

    var summaryLine: String {
        "\(moodEmoji) Mood \(moodRating)/10 · \(activity.displayName) · \(socialContext.displayName)"
    }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}