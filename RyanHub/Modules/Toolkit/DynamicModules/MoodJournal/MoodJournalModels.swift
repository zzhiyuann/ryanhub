import Foundation

// MARK: - MoodJournal Models

enum PrimaryEmotion: String, Codable, CaseIterable, Identifiable {
    case happy
    case calm
    case excited
    case grateful
    case hopeful
    case neutral
    case tired
    case anxious
    case stressed
    case sad
    case angry
    case lonely
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .excited: return "Excited"
        case .grateful: return "Grateful"
        case .hopeful: return "Hopeful"
        case .neutral: return "Neutral"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .stressed: return "Stressed"
        case .sad: return "Sad"
        case .angry: return "Angry"
        case .lonely: return "Lonely"
        }
    }
    var icon: String {
        switch self {
        case .happy: return "face.smiling"
        case .calm: return "leaf"
        case .excited: return "star"
        case .grateful: return "heart"
        case .hopeful: return "sunrise"
        case .neutral: return "face.dashed"
        case .tired: return "moon.zzz"
        case .anxious: return "waveform.path.ecg"
        case .stressed: return "bolt"
        case .sad: return "cloud.rain"
        case .angry: return "flame"
        case .lonely: return "person.slash"
        }
    }
}

enum MoodContext: String, Codable, CaseIterable, Identifiable {
    case work
    case social
    case exercise
    case rest
    case creative
    case outdoors
    case family
    case commute
    case eating
    case learning
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .social: return "Social"
        case .exercise: return "Exercise"
        case .rest: return "Rest"
        case .creative: return "Creative"
        case .outdoors: return "Outdoors"
        case .family: return "Family"
        case .commute: return "Commute"
        case .eating: return "Eating"
        case .learning: return "Learning"
        }
    }
    var icon: String {
        switch self {
        case .work: return "laptopcomputer"
        case .social: return "person.2"
        case .exercise: return "figure.run"
        case .rest: return "bed.double"
        case .creative: return "paintbrush"
        case .outdoors: return "sun.max"
        case .family: return "house"
        case .commute: return "car"
        case .eating: return "fork.knife"
        case .learning: return "book"
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
    var primaryEmotion: PrimaryEmotion
    var energyLevel: Int
    var context: MoodContext
    var sleepQuality: Int
    var gratitudeNote: String
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(moodRating)")
        parts.append("\(primaryEmotion)")
        parts.append("\(energyLevel)")
        parts.append("\(context)")
        parts.append("\(sleepQuality)")
        parts.append("\(gratitudeNote)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
