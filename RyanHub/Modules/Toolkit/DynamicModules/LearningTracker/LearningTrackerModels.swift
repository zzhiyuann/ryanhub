import Foundation

// MARK: - LearningTracker Models

enum LearningCategory: String, Codable, CaseIterable, Identifiable {
    case technology
    case language
    case music
    case art
    case business
    case science
    case health
    case math
    case writing
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .technology: return "Technology"
        case .language: return "Language"
        case .music: return "Music"
        case .art: return "Art & Design"
        case .business: return "Business"
        case .science: return "Science"
        case .health: return "Health & Fitness"
        case .math: return "Mathematics"
        case .writing: return "Writing"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .technology: return "desktopcomputer"
        case .language: return "character.book.closed"
        case .music: return "music.note"
        case .art: return "paintpalette"
        case .business: return "briefcase"
        case .science: return "atom"
        case .health: return "heart.circle"
        case .math: return "function"
        case .writing: return "pencil.line"
        case .other: return "square.grid.2x2"
        }
    }
}

enum LearningSessionType: String, Codable, CaseIterable, Identifiable {
    case lecture
    case reading
    case practice
    case project
    case review
    case quiz
    case tutorial
    case workshop
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .lecture: return "Lecture / Video"
        case .reading: return "Reading"
        case .practice: return "Hands-on Practice"
        case .project: return "Project Work"
        case .review: return "Review / Revision"
        case .quiz: return "Quiz / Test"
        case .tutorial: return "Tutorial"
        case .workshop: return "Workshop / Lab"
        }
    }
    var icon: String {
        switch self {
        case .lecture: return "play.rectangle"
        case .reading: return "book"
        case .practice: return "hammer"
        case .project: return "folder"
        case .review: return "arrow.counterclockwise"
        case .quiz: return "checkmark.circle"
        case .tutorial: return "graduationcap"
        case .workshop: return "wrench.and.screwdriver"
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
    var subjectName: String
    var category: LearningCategory
    var sessionType: LearningSessionType
    var durationMinutes: Int
    var focusRating: Int
    var progressPercent: Int
    var keyTakeaway: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(subjectName)")
        parts.append("\(category)")
        parts.append("\(sessionType)")
        parts.append("\(durationMinutes)")
        parts.append("\(focusRating)")
        parts.append("\(progressPercent)")
        parts.append("\(keyTakeaway)")
        return parts.joined(separator: " | ")
    }
}
