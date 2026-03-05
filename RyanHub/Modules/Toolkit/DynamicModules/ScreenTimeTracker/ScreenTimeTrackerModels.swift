import Foundation

// MARK: - Enums

enum ScreenCategory: String, CaseIterable, Codable, Identifiable {
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
        case .socialMedia:    return "Social Media"
        case .entertainment:  return "Entertainment"
        case .productivity:   return "Productivity"
        case .communication:  return "Communication"
        case .gaming:         return "Gaming"
        case .education:      return "Education"
        case .news:           return "News & Reading"
        case .shopping:       return "Shopping"
        case .other:          return "Other"
        }
    }

    var icon: String {
        switch self {
        case .socialMedia:    return "bubble.left.and.bubble.right.fill"
        case .entertainment:  return "play.tv.fill"
        case .productivity:   return "briefcase.fill"
        case .communication:  return "message.fill"
        case .gaming:         return "gamecontroller.fill"
        case .education:      return "graduationcap.fill"
        case .news:           return "newspaper.fill"
        case .shopping:       return "cart.fill"
        case .other:          return "ellipsis.circle.fill"
        }
    }
}

enum UsageIntent: String, CaseIterable, Codable, Identifiable {
    case intentional
    case habitual
    case mindless

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .intentional: return "Intentional"
        case .habitual:    return "Habitual"
        case .mindless:    return "Mindless Scrolling"
        }
    }

    var icon: String {
        switch self {
        case .intentional: return "target"
        case .habitual:    return "arrow.triangle.2.circlepath"
        case .mindless:    return "arrow.down.circle.fill"
        }
    }

    var isMindless: Bool { self == .mindless }
    var isIntentional: Bool { self == .intentional }
}

enum DeviceType: String, CaseIterable, Codable, Identifiable {
    case phone
    case tablet
    case computer
    case tv

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .phone:    return "Phone"
        case .tablet:   return "Tablet"
        case .computer: return "Computer"
        case .tv:       return "TV"
        }
    }

    var icon: String {
        switch self {
        case .phone:    return "iphone"
        case .tablet:   return "ipad"
        case .computer: return "laptopcomputer"
        case .tv:       return "tv.fill"
        }
    }
}

// MARK: - Entry

struct ScreenTimeTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var duration: Double = 0.5
    var category: ScreenCategory = .other
    var intentionality: UsageIntent = .intentional
    var device: DeviceType = .phone
    var appName: String = ""
    var note: String = ""

    // MARK: Computed

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateOnly: String { String(date.prefix(10)) }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var durationFormatted: String {
        let hours = Int(duration)
        let minutes = Int((duration - Double(hours)) * 60)
        if hours == 0 {
            return "\(minutes)m"
        } else if minutes == 0 {
            return "\(hours)h"
        } else {
            return "\(hours)h \(minutes)m"
        }
    }

    var summaryLine: String {
        var parts: [String] = ["\(durationFormatted) · \(category.displayName)"]
        if !appName.isEmpty { parts.append(appName) }
        parts.append(intentionality.displayName)
        return parts.joined(separator: " · ")
    }

    var isMindsless: Bool { intentionality == .mindless }
    var isIntentional: Bool { intentionality == .intentional }

    var weekday: Int? {
        guard let d = parsedDate else { return nil }
        return Calendar.current.component(.weekday, from: d)
    }

    var isWeekend: Bool {
        guard let wd = weekday else { return false }
        return wd == 1 || wd == 7
    }
}

// MARK: - Goal Progress Helpers

extension Double {
    /// Maps screen time progress to a ring color label (for use with Color lookup).
    /// Returns "green", "yellow", or "red" based on goal percentage consumed.
    func screenTimeRingColorName() -> String {
        if self < 0.6 { return "green" }
        if self < 0.9 { return "yellow" }
        return "red"
    }
}

// MARK: - Day Summary

struct ScreenTimeDaySummary {
    let dateString: String
    let entries: [ScreenTimeTrackerEntry]
    let dailyGoal: Double

    var totalHours: Double {
        entries.reduce(0) { $0 + $1.duration }
    }

    var isUnderGoal: Bool { totalHours <= dailyGoal }

    var overUnderHours: Double { totalHours - dailyGoal }

    var goalProgress: Double { min(totalHours / max(dailyGoal, 0.01), 2.0) }

    var categoryBreakdown: [(ScreenCategory, Double)] {
        var map: [ScreenCategory: Double] = [:]
        for entry in entries {
            map[entry.category, default: 0] += entry.duration
        }
        return map.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var mindlessHours: Double {
        entries.filter { $0.intentionality == .mindless }.reduce(0) { $0 + $1.duration }
    }

    var intentionalHours: Double {
        entries.filter { $0.intentionality == .intentional }.reduce(0) { $0 + $1.duration }
    }

    var countsByDevice: [(DeviceType, Double)] {
        var map: [DeviceType: Double] = [:]
        for entry in entries {
            map[entry.device, default: 0] += entry.duration
        }
        return map.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    var qualifiesForStreak: Bool { isUnderGoal && !entries.isEmpty }
}

// MARK: - Streak Milestone

struct ScreenTimeStreakMilestone: Equatable {
    let days: Int
    let label: String

    static let milestones: [Int] = [3, 7, 14, 30, 60, 90]

    static func milestone(for streak: Int) -> ScreenTimeStreakMilestone? {
        guard let days = milestones.filter({ $0 <= streak }).max() else { return nil }
        return ScreenTimeStreakMilestone(days: days, label: "\(days)-day streak")
    }
}