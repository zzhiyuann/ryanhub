import Foundation

// MARK: - DailyAffirmations Models

enum AffirmationCategory: String, Codable, CaseIterable, Identifiable {
    case selfWorth
    case gratitude
    case abundance
    case health
    case relationships
    case career
    case courage
    case peace
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .selfWorth: return "Self-Worth"
        case .gratitude: return "Gratitude"
        case .abundance: return "Abundance"
        case .health: return "Health & Body"
        case .relationships: return "Relationships"
        case .career: return "Career & Purpose"
        case .courage: return "Courage & Growth"
        case .peace: return "Peace & Calm"
        }
    }
    var icon: String {
        switch self {
        case .selfWorth: return "heart.fill"
        case .gratitude: return "hands.sparkles.fill"
        case .abundance: return "sparkles"
        case .health: return "figure.mind.and.body"
        case .relationships: return "person.2.fill"
        case .career: return "briefcase.fill"
        case .courage: return "flame.fill"
        case .peace: return "leaf.fill"
        }
    }
}

enum PracticeTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case midday
    case evening
    case bedtime
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        case .bedtime: return "Bedtime"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .midday: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .bedtime: return "moon.stars.fill"
        }
    }
}

struct DailyAffirmationsEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var affirmation: String
    var category: AffirmationCategory
    var moodBefore: Int
    var moodAfter: Int
    var resonance: Int
    var practiceTime: PracticeTime
    var repetitions: Int
    var isFavorite: Bool
    var reflection: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(affirmation)")
        parts.append("\(category)")
        parts.append("\(moodBefore)")
        parts.append("\(moodAfter)")
        parts.append("\(resonance)")
        parts.append("\(practiceTime)")
        parts.append("\(repetitions)")
        parts.append("\(isFavorite)")
        parts.append("\(reflection)")
        return parts.joined(separator: " | ")
    }
}
