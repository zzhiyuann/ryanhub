import Foundation

// MARK: - FocusSession Models

enum FocusCategory: String, Codable, CaseIterable, Identifiable {
    case work
    case study
    case creative
    case coding
    case writing
    case reading
    case personal
    case health
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .creative: return "Creative"
        case .coding: return "Coding"
        case .writing: return "Writing"
        case .reading: return "Reading"
        case .personal: return "Personal"
        case .health: return "Health"
        }
    }
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil.line"
        case .reading: return "text.book.closed.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        }
    }
}

enum SessionType: String, Codable, CaseIterable, Identifiable {
    case deepWork
    case shallowWork
    case review
    case planning
    case brainstorm
    case practice
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .deepWork: return "Deep Work"
        case .shallowWork: return "Shallow Work"
        case .review: return "Review"
        case .planning: return "Planning"
        case .brainstorm: return "Brainstorm"
        case .practice: return "Practice"
        }
    }
    var icon: String {
        switch self {
        case .deepWork: return "bolt.fill"
        case .shallowWork: return "bolt.slash.fill"
        case .review: return "arrow.clockwise"
        case .planning: return "map.fill"
        case .brainstorm: return "lightbulb.fill"
        case .practice: return "figure.strengthtraining.traditional"
        }
    }
}

struct FocusSessionEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var duration: Int
    var task: String
    var category: FocusCategory
    var sessionType: SessionType
    var quality: Int
    var completedFull: Bool
    var distractions: Int
    var plannedDuration: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(duration)")
        parts.append("\(task)")
        parts.append("\(category)")
        parts.append("\(sessionType)")
        parts.append("\(quality)")
        parts.append("\(completedFull)")
        parts.append("\(distractions)")
        parts.append("\(plannedDuration)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
