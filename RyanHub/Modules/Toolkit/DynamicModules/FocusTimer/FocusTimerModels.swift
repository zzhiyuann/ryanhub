import Foundation

// MARK: - FocusTimer Models

enum FocusCategory: String, Codable, CaseIterable, Identifiable {
    case work
    case study
    case creative
    case coding
    case writing
    case personal
    case health
    case admin
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .study: return "Study"
        case .creative: return "Creative"
        case .coding: return "Coding"
        case .writing: return "Writing"
        case .personal: return "Personal"
        case .health: return "Health"
        case .admin: return "Admin"
        }
    }
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .study: return "book.fill"
        case .creative: return "paintbrush.fill"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .writing: return "pencil.line"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .admin: return "folder.fill"
        }
    }
}

struct FocusTimerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var taskName: String
    var category: FocusCategory
    var duration: Int
    var completed: Bool
    var quality: Int
    var distractionCount: Int
    var breakDuration: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(taskName)")
        parts.append("\(category)")
        parts.append("\(duration)")
        parts.append("\(completed)")
        parts.append("\(quality)")
        parts.append("\(distractionCount)")
        parts.append("\(breakDuration)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
