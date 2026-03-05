import Foundation

// MARK: - Enums

enum FocusCategory: String, CaseIterable, Codable, Identifiable {
    case coding
    case writing
    case studying
    case design
    case planning
    case research
    case meeting
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coding:   return "Coding"
        case .writing:  return "Writing"
        case .studying: return "Studying"
        case .design:   return "Design"
        case .planning: return "Planning"
        case .research: return "Research"
        case .meeting:  return "Meeting"
        case .other:    return "Other"
        }
    }

    var icon: String {
        switch self {
        case .coding:   return "chevron.left.forwardslash.chevron.right"
        case .writing:  return "pencil.line"
        case .studying: return "book.fill"
        case .design:   return "paintbrush.fill"
        case .planning: return "list.clipboard.fill"
        case .research: return "magnifyingglass"
        case .meeting:  return "person.2.fill"
        case .other:    return "ellipsis.circle.fill"
        }
    }
}

enum SessionType: String, CaseIterable, Codable, Identifiable {
    case pomodoro
    case deepWork
    case shortBurst
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pomodoro:   return "Pomodoro (25m)"
        case .deepWork:   return "Deep Work (50m)"
        case .shortBurst: return "Short Burst (15m)"
        case .custom:     return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .pomodoro:   return "timer"
        case .deepWork:   return "brain.head.profile"
        case .shortBurst: return "bolt.fill"
        case .custom:     return "slider.horizontal.3"
        }
    }

    var defaultDurationMinutes: Int {
        switch self {
        case .pomodoro:   return 25
        case .deepWork:   return 50
        case .shortBurst: return 15
        case .custom:     return 30
        }
    }
}

// MARK: - Main Entry

struct FocusTimerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var durationMinutes: Int = 25
    var task: String = ""
    var category: FocusCategory = .coding
    var sessionType: SessionType = .pomodoro
    var focusQuality: Int = 3
    var distractionCount: Int = 0
    var completed: Bool = true
    var startTime: Date = Date()
    var notes: String = ""

    // MARK: - Computed Properties

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var formattedStartTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: startTime)
    }

    var formattedDuration: String {
        guard durationMinutes > 0 else { return "0m" }
        let hours = durationMinutes / 60
        let minutes = durationMinutes % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }

    var summaryLine: String {
        let taskLabel = task.isEmpty ? sessionType.displayName : task
        let status = completed ? "✓" : "✗"
        return "\(status) \(formattedDuration) · \(taskLabel) · \(category.displayName) · Q\(focusQuality)"
    }

    var qualityLabel: String {
        switch focusQuality {
        case 1: return "Distracted"
        case 2: return "Below Average"
        case 3: return "Average"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }

    var qualityStars: String {
        let clamped = max(0, min(5, focusQuality))
        return String(repeating: "★", count: clamped) + String(repeating: "☆", count: 5 - clamped)
    }

    var entryDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    /// "yyyy-MM-dd" key for grouping entries by calendar day
    var dayKey: String { String(date.prefix(10)) }

    var distractionLabel: String {
        switch distractionCount {
        case 0:       return "No distractions"
        case 1:       return "1 distraction"
        default:      return "\(distractionCount) distractions"
        }
    }
}

// MARK: - Chart Data

struct DailyFocusPoint: Identifiable {
    let id: String
    let date: Date
    let totalMinutes: Int
    let sessionCount: Int

    init(date: Date, totalMinutes: Int, sessionCount: Int) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        self.id = f.string(from: date)
        self.date = date
        self.totalMinutes = totalMinutes
        self.sessionCount = sessionCount
    }

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .short
        return f.string(from: date)
    }

    var formattedTotalMinutes: String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h" }
        return "\(minutes)m"
    }
}