import Foundation

// MARK: - MoodJournal Models

enum EmotionType: String, Codable, CaseIterable, Identifiable {
    case joyful
    case content
    case calm
    case grateful
    case excited
    case hopeful
    case neutral
    case tired
    case stressed
    case anxious
    case sad
    case frustrated
    case angry
    case lonely
    case overwhelmed
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .joyful: return "Joyful"
        case .content: return "Content"
        case .calm: return "Calm"
        case .grateful: return "Grateful"
        case .excited: return "Excited"
        case .hopeful: return "Hopeful"
        case .neutral: return "Neutral"
        case .tired: return "Tired"
        case .stressed: return "Stressed"
        case .anxious: return "Anxious"
        case .sad: return "Sad"
        case .frustrated: return "Frustrated"
        case .angry: return "Angry"
        case .lonely: return "Lonely"
        case .overwhelmed: return "Overwhelmed"
        }
    }
    var icon: String {
        switch self {
        case .joyful: return "sun.max.fill"
        case .content: return "face.smiling"
        case .calm: return "leaf.fill"
        case .grateful: return "heart.fill"
        case .excited: return "sparkles"
        case .hopeful: return "sunrise.fill"
        case .neutral: return "circle.fill"
        case .tired: return "moon.zzz.fill"
        case .stressed: return "bolt.fill"
        case .anxious: return "waveform.path.ecg"
        case .sad: return "cloud.rain.fill"
        case .frustrated: return "flame.fill"
        case .angry: return "exclamationmark.triangle.fill"
        case .lonely: return "person.fill.xmark"
        case .overwhelmed: return "tornado"
        }
    }
}

enum ActivityTag: String, Codable, CaseIterable, Identifiable {
    case work
    case exercise
    case socializing
    case reading
    case meditation
    case cooking
    case outdoors
    case music
    case gaming
    case family
    case creative
    case shopping
    case travel
    case selfCare
    case learning
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .work: return "Work"
        case .exercise: return "Exercise"
        case .socializing: return "Socializing"
        case .reading: return "Reading"
        case .meditation: return "Meditation"
        case .cooking: return "Cooking"
        case .outdoors: return "Outdoors"
        case .music: return "Music"
        case .gaming: return "Gaming"
        case .family: return "Family"
        case .creative: return "Creative"
        case .shopping: return "Shopping"
        case .travel: return "Travel"
        case .selfCare: return "Self Care"
        case .learning: return "Learning"
        }
    }
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .exercise: return "figure.run"
        case .socializing: return "person.2.fill"
        case .reading: return "book.fill"
        case .meditation: return "figure.mind.and.body"
        case .cooking: return "frying.pan.fill"
        case .outdoors: return "tree.fill"
        case .music: return "music.note"
        case .gaming: return "gamecontroller.fill"
        case .family: return "house.fill"
        case .creative: return "paintbrush.fill"
        case .shopping: return "cart.fill"
        case .travel: return "airplane"
        case .selfCare: return "sparkles"
        case .learning: return "graduationcap.fill"
        }
    }
}

enum SocialContext: String, Codable, CaseIterable, Identifiable {
    case alone
    case partner
    case friends
    case family
    case coworkers
    case strangers
    case crowd
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .alone: return "Alone"
        case .partner: return "Partner"
        case .friends: return "Friends"
        case .family: return "Family"
        case .coworkers: return "Coworkers"
        case .strangers: return "Strangers"
        case .crowd: return "Crowd"
        }
    }
    var icon: String {
        switch self {
        case .alone: return "person.fill"
        case .partner: return "heart.circle.fill"
        case .friends: return "person.3.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .coworkers: return "person.2.badge.gearshape.fill"
        case .strangers: return "person.fill.questionmark"
        case .crowd: return "person.3.sequence.fill"
        }
    }
}

enum WeatherType: String, Codable, CaseIterable, Identifiable {
    case sunny
    case cloudy
    case rainy
    case stormy
    case snowy
    case windy
    case foggy
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .sunny: return "Sunny"
        case .cloudy: return "Cloudy"
        case .rainy: return "Rainy"
        case .stormy: return "Stormy"
        case .snowy: return "Snowy"
        case .windy: return "Windy"
        case .foggy: return "Foggy"
        }
    }
    var icon: String {
        switch self {
        case .sunny: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rainy: return "cloud.rain.fill"
        case .stormy: return "cloud.bolt.fill"
        case .snowy: return "cloud.snow.fill"
        case .windy: return "wind"
        case .foggy: return "cloud.fog.fill"
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
    var moodLevel: Int
    var emotion: EmotionType
    var secondaryEmotion: EmotionType?
    var energyLevel: Int
    var anxietyLevel: Int
    var activities: [ActivityTag]
    var socialContext: SocialContext
    var sleepQuality: Int
    var weather: WeatherType
    var reflection: String
    var gratitude: String
    var logTime: Date

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(moodLevel)")
        parts.append("\(emotion)")
        if let v = secondaryEmotion { parts.append("\(v)") }
        parts.append("\(energyLevel)")
        parts.append("\(anxietyLevel)")
        parts.append("\(activities)")
        parts.append("\(socialContext)")
        parts.append("\(sleepQuality)")
        parts.append("\(weather)")
        parts.append("\(reflection)")
        parts.append("\(gratitude)")
        parts.append("\(logTime)")
        return parts.joined(separator: " | ")
    }
}
