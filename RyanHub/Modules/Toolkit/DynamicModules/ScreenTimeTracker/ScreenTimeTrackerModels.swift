import Foundation

// MARK: - ScreenTimeTracker Models

enum ScreenTimeCategory: String, Codable, CaseIterable, Identifiable {
    case socialMedia
    case entertainment
    case productivity
    case communication
    case gaming
    case education
    case news
    case shopping
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .socialMedia: return "Social Media"
        case .entertainment: return "Entertainment"
        case .productivity: return "Productivity"
        case .communication: return "Communication"
        case .gaming: return "Gaming"
        case .education: return "Education"
        case .news: return "News & Reading"
        case .shopping: return "Shopping"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .socialMedia: return "bubble.left.and.bubble.right.fill"
        case .entertainment: return "play.tv.fill"
        case .productivity: return "briefcase.fill"
        case .communication: return "message.fill"
        case .gaming: return "gamecontroller.fill"
        case .education: return "book.fill"
        case .news: return "newspaper.fill"
        case .shopping: return "cart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

struct ScreenTimeTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var category: ScreenTimeCategory
    var durationMinutes: Int
    var intentional: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(category)")
        parts.append("\(durationMinutes)")
        parts.append("\(intentional)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
