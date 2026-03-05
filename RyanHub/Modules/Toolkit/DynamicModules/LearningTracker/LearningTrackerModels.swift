import Foundation

// MARK: - LearningTracker Models

enum LearningCategory: String, Codable, CaseIterable, Identifiable {
    case programming
    case language
    case music
    case design
    case business
    case science
    case math
    case writing
    case fitness
    case cooking
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .programming: return "Programming"
        case .language: return "Language"
        case .music: return "Music"
        case .design: return "Design"
        case .business: return "Business"
        case .science: return "Science"
        case .math: return "Mathematics"
        case .writing: return "Writing"
        case .fitness: return "Fitness / Health"
        case .cooking: return "Cooking"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .programming: return "chevron.left.forwardslash.chevron.right"
        case .language: return "character.book.closed"
        case .music: return "music.note"
        case .design: return "paintpalette"
        case .business: return "briefcase"
        case .science: return "atom"
        case .math: return "function"
        case .writing: return "pencil.line"
        case .fitness: return "figure.run"
        case .cooking: return "frying.pan"
        case .other: return "ellipsis.circle"
        }
    }
}

enum ResourceType: String, Codable, CaseIterable, Identifiable {
    case onlineCourse
    case book
    case video
    case podcast
    case practice
    case article
    case mentorship
    case flashcards
    case project
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .onlineCourse: return "Online Course"
        case .book: return "Book"
        case .video: return "Video / Tutorial"
        case .podcast: return "Podcast"
        case .practice: return "Hands-on Practice"
        case .article: return "Article / Blog"
        case .mentorship: return "Mentorship / Class"
        case .flashcards: return "Flashcards / Review"
        case .project: return "Project Work"
        }
    }
    var icon: String {
        switch self {
        case .onlineCourse: return "play.rectangle"
        case .book: return "book"
        case .video: return "video"
        case .podcast: return "headphones"
        case .practice: return "hammer"
        case .article: return "doc.text"
        case .mentorship: return "person.2"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .project: return "wrench.and.screwdriver"
        }
    }
}

struct LearningTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var subject: String
    var category: LearningCategory
    var durationMinutes: Int
    var resourceType: ResourceType
    var resourceName: String
    var confidenceLevel: Int
    var completionPercent: Int
    var sessionGoalMet: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(subject)")
        parts.append("\(category)")
        parts.append("\(durationMinutes)")
        parts.append("\(resourceType)")
        parts.append("\(resourceName)")
        parts.append("\(confidenceLevel)")
        parts.append("\(completionPercent)")
        parts.append("\(sessionGoalMet)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
