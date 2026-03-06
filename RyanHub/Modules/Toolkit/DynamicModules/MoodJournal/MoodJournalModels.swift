import Foundation

// MARK: - MoodJournal Entry

struct MoodJournalEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var rating: Int = 5
    var emotion: Emotion = .neutral
    var energyLevel: Int = 5
    var notes: String = ""

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .short
        return display.string(from: d)
    }

    var summaryLine: String {
        let moodDesc: String
        switch rating {
        case 1...3: moodDesc = "Low"
        case 4...6: moodDesc = "Moderate"
        case 7...8: moodDesc = "Good"
        case 9...10: moodDesc = "Great"
        default: moodDesc = "Unknown"
        }
        return "\(moodDesc) mood · \(emotion.displayName)"
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var calendarDate: Date? {
        guard let d = parsedDate else { return nil }
        return Calendar.current.startOfDay(for: d)
    }

    var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return "" }
        let display = DateFormatter()
        display.dateFormat = "h:mm a"
        return display.string(from: d)
    }

    var dayOfWeek: String {
        guard let d = parsedDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    var moodFace: String {
        switch rating {
        case 1...2: return "face.smiling.inverse"
        case 3...4: return "face.dashed"
        case 5...6: return "face.dashed"
        case 7...8: return "face.smiling"
        case 9...10: return "face.smiling.fill"
        default: return "face.dashed"
        }
    }

    var isPositiveMood: Bool {
        rating >= 7
    }

    var isNegativeMood: Bool {
        rating <= 3
    }

    var energyDescription: String {
        switch energyLevel {
        case 1...3: return "Low Energy"
        case 4...6: return "Moderate Energy"
        case 7...8: return "High Energy"
        case 9...10: return "Very High Energy"
        default: return "Unknown"
        }
    }

    var hasNotes: Bool {
        !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

// MARK: - Emotion Enum

enum Emotion: String, CaseIterable, Codable, Identifiable {
    case happy
    case calm
    case excited
    case grateful
    case neutral
    case anxious
    case sad
    case angry
    case stressed
    case tired

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .excited: return "Excited"
        case .grateful: return "Grateful"
        case .neutral: return "Neutral"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .stressed: return "Stressed"
        case .tired: return "Tired"
        }
    }

    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .calm: return "leaf"
        case .excited: return "star"
        case .grateful: return "heart"
        case .neutral: return "face.dashed"
        case .anxious: return "bolt.heart"
        case .sad: return "cloud.rain"
        case .angry: return "flame"
        case .stressed: return "waveform.path.ecg"
        case .tired: return "moon.zzz"
        }
    }

    var isPositive: Bool {
        switch self {
        case .happy, .calm, .excited, .grateful: return true
        default: return false
        }
    }

    var isNegative: Bool {
        switch self {
        case .anxious, .sad, .angry, .stressed: return true
        default: return false
        }
    }

    var valence: Double {
        switch self {
        case .happy: return 0.8
        case .calm: return 0.6
        case .excited: return 0.9
        case .grateful: return 0.7
        case .neutral: return 0.0
        case .anxious: return -0.6
        case .sad: return -0.7
        case .angry: return -0.8
        case .stressed: return -0.5
        case .tired: return -0.3
        }
    }
}