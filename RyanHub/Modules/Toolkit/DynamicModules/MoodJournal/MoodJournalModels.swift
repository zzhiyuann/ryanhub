import Foundation

// MARK: - MoodJournal Models

enum MoodEmotion: String, Codable, CaseIterable, Identifiable {
    case happy
    case calm
    case grateful
    case excited
    case neutral
    case tired
    case anxious
    case stressed
    case sad
    case angry
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .happy: return "Happy"
        case .calm: return "Calm"
        case .grateful: return "Grateful"
        case .excited: return "Excited"
        case .neutral: return "Neutral"
        case .tired: return "Tired"
        case .anxious: return "Anxious"
        case .stressed: return "Stressed"
        case .sad: return "Sad"
        case .angry: return "Angry"
        }
    }
    var icon: String {
        switch self {
        case .happy: return "face.smiling.inverse"
        case .calm: return "leaf.fill"
        case .grateful: return "heart.fill"
        case .excited: return "star.fill"
        case .neutral: return "face.dashed"
        case .tired: return "powersleep"
        case .anxious: return "waveform.path.ecg"
        case .stressed: return "bolt.fill"
        case .sad: return "cloud.rain.fill"
        case .angry: return "flame.fill"
        }
    }
}

enum MoodActivity: String, Codable, CaseIterable, Identifiable {
    case work
    case exercise
    case socializing
    case reading
    case nature
    case creative
    case family
    case rest
    case travel
    case learning
    case cooking
    case meditation
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .exercise: return "Exercise"
        case .socializing: return "Socializing"
        case .reading: return "Reading"
        case .nature: return "Nature"
        case .creative: return "Creative"
        case .family: return "Family"
        case .rest: return "Rest"
        case .travel: return "Travel"
        case .learning: return "Learning"
        case .cooking: return "Cooking"
        case .meditation: return "Meditation"
        }
    }
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .exercise: return "figure.run"
        case .socializing: return "person.2.fill"
        case .reading: return "book.fill"
        case .nature: return "leaf.fill"
        case .creative: return "paintbrush.fill"
        case .family: return "house.fill"
        case .rest: return "bed.double.fill"
        case .travel: return "car.fill"
        case .learning: return "graduationcap.fill"
        case .cooking: return "fork.knife"
        case .meditation: return "brain.head.profile.fill"
        }
    }
}

enum SocialLevel: String, Codable, CaseIterable, Identifiable {
    case alone
    case onePerson
    case smallGroup
    case largeGroup
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .alone: return "Alone"
        case .onePerson: return "One Person"
        case .smallGroup: return "Small Group"
        case .largeGroup: return "Large Group"
        }
    }
    var icon: String {
        switch self {
        case .alone: return "person.fill"
        case .onePerson: return "person.2.fill"
        case .smallGroup: return "person.3.fill"
        case .largeGroup: return "person.3.sequence.fill"
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
    var rating: Int
    var energy: Int
    var emotion: MoodEmotion
    var activities: [MoodActivity]
    var sleepQuality: Int
    var socialLevel: SocialLevel
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(rating)")
        parts.append("\(energy)")
        parts.append("\(emotion)")
        parts.append("\(activities)")
        parts.append("\(sleepQuality)")
        parts.append("\(socialLevel)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
