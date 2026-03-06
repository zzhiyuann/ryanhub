import Foundation

// MARK: - MoodJournal Models

enum Emotion: String, Codable, CaseIterable, Identifiable {
    case ecstatic
    case happy
    case grateful
    case calm
    case neutral
    case anxious
    case sad
    case angry
    case stressed
    case lonely
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ecstatic: return "Ecstatic"
        case .happy: return "Happy"
        case .grateful: return "Grateful"
        case .calm: return "Calm"
        case .neutral: return "Neutral"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .stressed: return "Stressed"
        case .lonely: return "Lonely"
        }
    }
    var icon: String {
        switch self {
        case .ecstatic: return "sparkles"
        case .happy: return "sun.max.fill"
        case .grateful: return "heart.fill"
        case .calm: return "leaf.fill"
        case .neutral: return "circle.fill"
        case .anxious: return "bolt.fill"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        case .stressed: return "waveform.path.ecg"
        case .lonely: return "moon.fill"
        }
    }
}

struct MoodJournalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var moodRating: Int
    var emotion: Emotion
    var energyLevel: Int
    var activities: String
    var note: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(moodRating)")
        parts.append("\(emotion)")
        parts.append("\(energyLevel)")
        parts.append("\(activities)")
        return parts.joined(separator: " | ")
    }
}
