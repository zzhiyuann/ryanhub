import Foundation

// MARK: - GratitudeJournal Models

enum GratitudeTheme: String, Codable, CaseIterable, Identifiable {
    case people
    case health
    case nature
    case work
    case experiences
    case home
    case food
    case learning
    case creativity
    case pets
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .people: return "People"
        case .health: return "Health"
        case .nature: return "Nature"
        case .work: return "Career"
        case .experiences: return "Experiences"
        case .home: return "Home & Comfort"
        case .food: return "Food & Drink"
        case .learning: return "Growth"
        case .creativity: return "Creativity"
        case .pets: return "Pets & Animals"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .people: return "person.2.fill"
        case .health: return "heart.fill"
        case .nature: return "leaf.fill"
        case .work: return "briefcase.fill"
        case .experiences: return "star.fill"
        case .home: return "house.fill"
        case .food: return "fork.knife"
        case .learning: return "brain.head.profile"
        case .creativity: return "paintbrush.fill"
        case .pets: return "pawprint.fill"
        case .other: return "ellipsis.circle.fill"
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
    var gratitudeOne: String
    var themeOne: GratitudeTheme
    var gratitudeTwo: String
    var themeTwo: GratitudeTheme
    var gratitudeThree: String
    var themeThree: GratitudeTheme
    var moodAfter: Int
    var reflection: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(gratitudeOne)")
        parts.append("\(themeOne)")
        parts.append("\(gratitudeTwo)")
        parts.append("\(themeTwo)")
        parts.append("\(gratitudeThree)")
        parts.append("\(themeThree)")
        parts.append("\(moodAfter)")
        parts.append("\(reflection)")
        return parts.joined(separator: " | ")
    }
}
