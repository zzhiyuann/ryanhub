import Foundation

// MARK: - Enums

enum DrinkType: String, CaseIterable, Codable, Identifiable {
    case water
    case coffee
    case tea
    case juice
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: return "Water"
        case .coffee: return "Coffee"
        case .tea: return "Tea"
        case .juice: return "Juice"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .water: return "drop.fill"
        case .coffee: return "mug.fill"
        case .tea: return "leaf.fill"
        case .juice: return "cup.and.saucer.fill"
        case .other: return "ellipsis.circle.fill"
        }
    }
}

// MARK: - Entry Model

struct HydrationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amount: Int = 250
    var drinkType: DrinkType = .water

    // MARK: - Computed Properties

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var formattedDate: String {
        guard let parsed = parsedDate else { return date }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: parsed)
    }

    var formattedTime: String {
        guard let parsed = parsedDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: parsed)
    }

    var summaryLine: String {
        "\(amount)ml \(drinkType.displayName)"
    }

    var isToday: Bool {
        guard let parsed = parsedDate else { return false }
        return Calendar.current.isDateInToday(parsed)
    }

    var calendarDay: String {
        guard let parsed = parsedDate else { return String(date.prefix(10)) }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: parsed)
    }
}

// MARK: - Quick Add Preset

struct HydrationPreset: Identifiable {
    let id: String
    let label: String
    let amount: Int
    let icon: String

    static let defaults: [HydrationPreset] = [
        HydrationPreset(id: "small", label: "Small Glass", amount: 200, icon: "drop.fill"),
        HydrationPreset(id: "glass", label: "Glass", amount: 250, icon: "drop.fill"),
        HydrationPreset(id: "large", label: "Large Glass", amount: 350, icon: "drop.fill"),
        HydrationPreset(id: "bottle", label: "Bottle", amount: 500, icon: "drop.fill")
    ]
}

// MARK: - Time Period

enum HydrationTimePeriod: String, CaseIterable {
    case morning
    case afternoon
    case evening
    case night

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        case .night: return "Night"
        }
    }

    var hourRange: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...23
        case .night: return 0...5
        }
    }

    static func from(hour: Int) -> HydrationTimePeriod {
        switch hour {
        case 6...11: return .morning
        case 12...17: return .afternoon
        case 18...23: return .evening
        default: return .night
        }
    }
}

// MARK: - Daily Summary

struct HydrationDaySummary: Identifiable {
    let date: Date
    let total: Int
    let dailyGoal: Int

    var id: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var metGoal: Bool {
        total >= dailyGoal
    }

    var progress: Double {
        guard dailyGoal > 0 else { return 0 }
        return Double(total) / Double(dailyGoal)
    }

    var dayLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: date)
    }
}

// MARK: - Drink Type Breakdown

struct DrinkTypeBreakdown: Identifiable {
    let drinkType: DrinkType
    let totalMl: Int
    let percentage: Double

    var id: String { drinkType.rawValue }
}

// MARK: - UserDefaults Keys

enum HydrationTrackerKeys {
    static let dailyGoal = "hydrationDailyGoal"
    static let defaultDailyGoal = 2000
    static let bestStreak = "hydrationBestStreak"
}