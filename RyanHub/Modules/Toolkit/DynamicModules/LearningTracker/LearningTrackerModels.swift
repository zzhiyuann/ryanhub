import Foundation

// MARK: - LearningTracker Models

enum LearningCategory: String, Codable, CaseIterable, Identifiable {
    case programming
    case language
    case music
    case design
    case business
    case science
    case writing
    case fitness
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
        case .writing: return "Writing"
        case .fitness: return "Fitness"
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
        case .writing: return "pencil.line"
        case .fitness: return "figure.run"
        case .other: return "sparkles"
        }
    }
}

enum LearningSessionType: String, Codable, CaseIterable, Identifiable {
    case videoLecture
    case reading
    case practice
    case project
    case review
    case mentoring
    case exam
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .videoLecture: return "Video / Lecture"
        case .reading: return "Reading"
        case .practice: return "Hands-on Practice"
        case .project: return "Project Work"
        case .review: return "Review / Flashcards"
        case .mentoring: return "Mentoring / Class"
        case .exam: return "Quiz / Exam"
        }
    }
    var icon: String {
        switch self {
        case .videoLecture: return "play.rectangle"
        case .reading: return "book"
        case .practice: return "hammer"
        case .project: return "folder"
        case .review: return "arrow.counterclockwise"
        case .mentoring: return "person.2"
        case .exam: return "checkmark.seal"
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
    var skillName: String
    var category: LearningCategory
    var sessionType: LearningSessionType
    var durationMinutes: Int
    var progressPercent: Int
    var confidenceRating: Int
    var milestone: String
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(skillName)")
        parts.append("\(category)")
        parts.append("\(sessionType)")
        parts.append("\(durationMinutes)")
        parts.append("\(progressPercent)")
        parts.append("\(confidenceRating)")
        parts.append("\(milestone)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
