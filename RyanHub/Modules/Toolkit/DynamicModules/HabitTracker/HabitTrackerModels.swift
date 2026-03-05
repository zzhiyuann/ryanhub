import Foundation

// MARK: - HabitTracker Models

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case mindfulness
    case fitness
    case learning
    case creativity
    case health
    case productivity
    case social
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .mindfulness: return "Mindfulness"
        case .fitness: return "Fitness"
        case .learning: return "Learning"
        case .creativity: return "Creativity"
        case .health: return "Health"
        case .productivity: return "Productivity"
        case .social: return "Social"
        }
    }
    var icon: String {
        switch self {
        case .mindfulness: return "brain.head.profile"
        case .fitness: return "figure.run"
        case .learning: return "book.fill"
        case .creativity: return "paintbrush.fill"
        case .health: return "heart.fill"
        case .productivity: return "bolt.fill"
        case .social: return "person.2.fill"
        }
    }
}

enum HabitTimeSlot: String, Codable, CaseIterable, Identifiable {
    case morning
    case afternoon
    case evening
    case anytime
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .anytime: return "Anytime"
        }
    }
    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .anytime: return "clock.fill"
        }
    }
}

struct HabitTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var habitName: String
    var category: HabitCategory
    var completed: Bool
    var durationMinutes: Int
    var difficulty: Int
    var timeSlot: HabitTimeSlot
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(habitName)")
        parts.append("\(category)")
        parts.append("\(completed)")
        parts.append("\(durationMinutes)")
        parts.append("\(difficulty)")
        parts.append("\(timeSlot)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
