import Foundation

// MARK: - GratitudeJournal Models

enum GratitudeCategory: String, Codable, CaseIterable, Identifiable {
    case people
    case health
    case work
    case nature
    case experiences
    case growth
    case home
    case creativity
    case simple
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
        case .home: return "Home & Comfort"
        case .creativity: return "Creativity"
        case .simple: return "Simple Pleasures"
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
        case .growth: return "arrow.up.heart.fill"
        case .home: return "house.fill"
        case .creativity: return "paintpalette.fill"
        case .simple: return "cup.and.saucer.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum EntryMood: String, Codable, CaseIterable, Identifiable {
    case joyful
    case content
    case peaceful
    case hopeful
    case reflective
    case neutral
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .joyful: return "Joyful"
        case .content: return "Content"
        case .peaceful: return "Peaceful"
        case .hopeful: return "Hopeful"
        case .reflective: return "Reflective"
        case .neutral: return "Neutral"
        }
    }
    var icon: String {
        switch self {
        case .joyful: return "sun.max.fill"
        case .content: return "face.smiling"
        case .peaceful: return "moon.stars.fill"
        case .hopeful: return "sunrise.fill"
        case .reflective: return "bubble.left.and.text.bubble.right"
        case .neutral: return "circle.fill"
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
    var depth: Int
    var mood: EntryMood

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(gratitudeText)")
        parts.append("\(category)")
        parts.append("\(depth)")
        parts.append("\(mood)")
        return parts.joined(separator: " | ")
    }
}
