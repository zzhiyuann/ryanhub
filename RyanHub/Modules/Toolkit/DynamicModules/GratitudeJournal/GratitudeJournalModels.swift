import Foundation

// MARK: - GratitudeJournal Models

enum GratitudeCategory: String, Codable, CaseIterable, Identifiable {
    case people
    case health
    case work
    case nature
    case experiences
    case growth
    case comforts
    case achievements
    case relationships
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .people: return "People"
        case .health: return "Health"
        case .work: return "Work & Career"
        case .nature: return "Nature"
        case .experiences: return "Experiences"
        case .growth: return "Personal Growth"
        case .comforts: return "Daily Comforts"
        case .achievements: return "Achievements"
        case .relationships: return "Relationships"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .people: return "person.2.fill"
        case .health: return "heart.fill"
        case .work: return "briefcase.fill"
        case .nature: return "leaf.fill"
        case .experiences: return "sparkles"
        case .growth: return "arrow.up.forward.circle.fill"
        case .comforts: return "cup.and.saucer.fill"
        case .achievements: return "trophy.fill"
        case .relationships: return "heart.circle.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum MoodLevel: String, Codable, CaseIterable, Identifiable {
    case amazing
    case good
    case okay
    case low
    case rough
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .amazing: return "Amazing"
        case .good: return "Good"
        case .okay: return "Okay"
        case .low: return "Low"
        case .rough: return "Rough"
        }
    }
    var icon: String {
        switch self {
        case .amazing: return "sun.max.fill"
        case .good: return "face.smiling"
        case .okay: return "cloud.sun.fill"
        case .low: return "cloud.fill"
        case .rough: return "cloud.rain.fill"
        }
    }
}

struct GratitudeJournalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var gratitudeText: String
    var category: GratitudeCategory
    var intensity: Int
    var mood: MoodLevel
    var isHighlight: Bool

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(gratitudeText)")
        parts.append("\(category)")
        parts.append("\(intensity)")
        parts.append("\(mood)")
        parts.append("\(isHighlight)")
        return parts.joined(separator: " | ")
    }
}
