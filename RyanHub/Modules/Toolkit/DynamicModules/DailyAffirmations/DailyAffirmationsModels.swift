import Foundation

// MARK: - DailyAffirmations Models

enum AffirmationCategory: String, Codable, CaseIterable, Identifiable {
    case selfLove
    case confidence
    case abundance
    case health
    case career
    case gratitude
    case relationships
    case growth
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .selfLove: return "Self-Love"
        case .confidence: return "Confidence"
        case .abundance: return "Abundance"
        case .health: return "Health"
        case .career: return "Career"
        case .gratitude: return "Gratitude"
        case .relationships: return "Relationships"
        case .growth: return "Growth"
        }
    }
    var icon: String {
        switch self {
        case .selfLove: return "heart.fill"
        case .confidence: return "bolt.fill"
        case .abundance: return "star.fill"
        case .health: return "leaf.fill"
        case .career: return "briefcase.fill"
        case .gratitude: return "hands.sparkles.fill"
        case .relationships: return "person.2.fill"
        case .growth: return "arrow.up.right.circle.fill"
        }
    }
}

enum PracticeTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "moon.fill"
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
    var practiceTime: PracticeTime
    var moodAfter: Int
    var spokenAloud: Bool
    var isFavorite: Bool
    var reflection: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(affirmation)")
        parts.append("\(category)")
        parts.append("\(practiceTime)")
        parts.append("\(moodAfter)")
        parts.append("\(spokenAloud)")
        parts.append("\(isFavorite)")
        parts.append("\(reflection)")
        return parts.joined(separator: " | ")
    }
}
