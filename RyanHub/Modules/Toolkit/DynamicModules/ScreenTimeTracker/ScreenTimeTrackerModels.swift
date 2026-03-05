import Foundation

// MARK: - ScreenTimeTracker Models

enum ScreenCategory: String, Codable, CaseIterable, Identifiable {
    case socialMedia
    case entertainment
    case gaming
    case productivity
    case communication
    case news
    case education
    case shopping
    case healthFitness
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .socialMedia: return "Social Media"
        case .entertainment: return "Entertainment"
        case .gaming: return "Gaming"
        case .productivity: return "Productivity"
        case .communication: return "Communication"
        case .news: return "News & Reading"
        case .education: return "Education"
        case .shopping: return "Shopping"
        case .healthFitness: return "Health & Fitness"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .socialMedia: return "bubble.left.and.bubble.right.fill"
        case .entertainment: return "play.tv.fill"
        case .gaming: return "gamecontroller.fill"
        case .productivity: return "hammer.fill"
        case .communication: return "message.fill"
        case .news: return "newspaper.fill"
        case .education: return "graduationcap.fill"
        case .shopping: return "cart.fill"
        case .healthFitness: return "heart.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

enum DeviceType: String, Codable, CaseIterable, Identifiable {
    case phone
    case tablet
    case computer
    case tv
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .phone: return "Phone"
        case .tablet: return "Tablet"
        case .computer: return "Computer"
        case .tv: return "TV / Streaming"
        }
    }
    var icon: String {
        switch self {
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .computer: return "laptopcomputer"
        case .tv: return "tv"
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
    var durationMinutes: Int
    var category: ScreenCategory
    var appName: String
    var wasIntentional: Bool
    var deviceType: DeviceType
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(durationMinutes)")
        parts.append("\(category)")
        parts.append("\(appName)")
        parts.append("\(wasIntentional)")
        parts.append("\(deviceType)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
