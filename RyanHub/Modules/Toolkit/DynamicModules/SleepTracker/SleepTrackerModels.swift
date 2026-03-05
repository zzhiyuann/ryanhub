import Foundation

// MARK: - SleepTracker Models

enum WakeMood: String, Codable, CaseIterable, Identifiable {
    case energized
    case refreshed
    case neutral
    case groggy
    case exhausted
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .energized: return "Energized"
        case .refreshed: return "Refreshed"
        case .neutral: return "Neutral"
        case .groggy: return "Groggy"
        case .exhausted: return "Exhausted"
        }
    }
    var icon: String {
        switch self {
        case .energized: return "bolt.fill"
        case .refreshed: return "sun.max.fill"
        case .neutral: return "minus.circle.fill"
        case .groggy: return "cloud.fill"
        case .exhausted: return "battery.0percent"
        }
    }
}

enum PreSleepActivity: String, Codable, CaseIterable, Identifiable {
    case reading
    case meditation
    case screenTime
    case exercise
    case socializing
    case none
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .reading: return "Reading"
        case .meditation: return "Meditation"
        case .screenTime: return "Screen Time"
        case .exercise: return "Exercise"
        case .socializing: return "Socializing"
        case .none: return "None / Other"
        }
    }
    var icon: String {
        switch self {
        case .reading: return "book.fill"
        case .meditation: return "figure.mind.and.body"
        case .screenTime: return "iphone"
        case .exercise: return "figure.run"
        case .socializing: return "person.2.fill"
        case .none: return "circle.dashed"
        }
    }
}

struct SleepTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var bedtime: Date
    var wakeTime: Date
    var qualityRating: Int
    var wakeMood: WakeMood
    var preSleepActivity: PreSleepActivity
    var dreamsRecalled: Bool
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(bedtime)")
        parts.append("\(wakeTime)")
        parts.append("\(qualityRating)")
        parts.append("\(wakeMood)")
        parts.append("\(preSleepActivity)")
        parts.append("\(dreamsRecalled)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
