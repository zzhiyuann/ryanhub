import Foundation

// MARK: - BeverageType

enum BeverageType: String, CaseIterable, Codable, Identifiable {
    case water
    case sparklingWater
    case tea
    case coffee
    case juice
    case milk
    case smoothie
    case sportsDrink
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water:         return "Water"
        case .sparklingWater: return "Sparkling Water"
        case .tea:           return "Tea"
        case .coffee:        return "Coffee"
        case .juice:         return "Juice"
        case .milk:          return "Milk"
        case .smoothie:      return "Smoothie"
        case .sportsDrink:   return "Sports Drink"
        case .other:         return "Other"
        }
    }

    var icon: String {
        switch self {
        case .water:         return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .tea:           return "cup.and.saucer.fill"
        case .coffee:        return "mug.fill"
        case .juice:         return "carrot.fill"
        case .milk:          return "cup.and.saucer.fill"
        case .smoothie:      return "blender.fill"
        case .sportsDrink:   return "bolt.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    /// Whether this beverage type is typically caffeinated (used for caffeine ratio logic).
    var isTypicallyCaffeinated: Bool {
        switch self {
        case .coffee, .tea, .sportsDrink: return true
        default: return false
        }
    }
}

// MARK: - ContainerPreset

enum ContainerPreset: String, CaseIterable, Codable, Identifiable {
    case small
    case medium
    case large
    case bottle
    case largeBottle
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:       return "Small Glass (200ml)"
        case .medium:      return "Medium Glass (350ml)"
        case .large:       return "Large Glass (500ml)"
        case .bottle:      return "Bottle (750ml)"
        case .largeBottle: return "Large Bottle (1000ml)"
        case .custom:      return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .small:       return "drop"
        case .medium:      return "drop.half.full"
        case .large:       return "drop.fill"
        case .bottle:      return "waterbottle.fill"
        case .largeBottle: return "waterbottle.fill"
        case .custom:      return "slider.horizontal.3"
        }
    }

    /// Pre-filled amount in ml; nil for .custom (user sets manually via stepper).
    var defaultAmountMl: Int? {
        switch self {
        case .small:       return 200
        case .medium:      return 350
        case .large:       return 500
        case .bottle:      return 750
        case .largeBottle: return 1000
        case .custom:      return nil
        }
    }
}

// MARK: - DrinkTemperature

enum DrinkTemperature: String, CaseIterable, Codable, Identifiable {
    case cold
    case room
    case warm
    case hot

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .cold: return "Cold"
        case .room: return "Room Temp"
        case .warm: return "Warm"
        case .hot:  return "Hot"
        }
    }

    var icon: String {
        switch self {
        case .cold: return "snowflake"
        case .room: return "thermometer.medium"
        case .warm: return "flame"
        case .hot:  return "flame.fill"
        }
    }
}

// MARK: - HydrationTrackerEntry

struct HydrationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    // Data fields
    var amountMl: Int = 250
    var beverageType: BeverageType = .water
    var containerPreset: ContainerPreset = .medium
    var temperature: DrinkTemperature = .room
    var timeConsumed: Date = Date()
    var caffeinated: Bool = false
    var notes: String = ""

    // MARK: Formatted / display helpers

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: timeConsumed)
    }

    /// "yyyy-MM-dd" key derived from timeConsumed — used for grouping entries by day.
    var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: timeConsumed)
    }

    /// Short human-readable amount: "750ml" or "1.5L".
    var shortAmountLabel: String {
        amountMl >= 1000
            ? String(format: "%.1fL", Double(amountMl) / 1000.0)
            : "\(amountMl)ml"
    }

    /// One-line summary shown in timeline cells.
    var summaryLine: String {
        "\(beverageType.displayName) · \(shortAmountLabel) · \(formattedTime)"
    }

    var amountOz: Double {
        Double(amountMl) / 29.5735
    }

    var amountCups: Double {
        Double(amountMl) / 236.588
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(timeConsumed)
    }

    /// True if this entry is caffeinated either by the explicit toggle or by beverage type default.
    var effectivelyCaffeinated: Bool {
        caffeinated || beverageType.isTypicallyCaffeinated
    }
}

// MARK: - InsightItem

struct InsightItem: Identifiable {
    let id: String
    let title: String
    let detail: String
    let icon: String
    let priority: InsightPriority

    init(id: String = UUID().uuidString,
         title: String,
         detail: String,
         icon: String,
         priority: InsightPriority = .medium) {
        self.id = id
        self.title = title
        self.detail = detail
        self.icon = icon
        self.priority = priority
    }

    enum InsightPriority: Int, Comparable {
        case high = 0, medium = 1, low = 2
        static func < (lhs: InsightPriority, rhs: InsightPriority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
}

// MARK: - HydrationDailySummary

/// Aggregated view of a single day's entries; used by ViewModel computations.
struct HydrationDailySummary {
    let date: Date
    let dayKey: String
    let entries: [HydrationTrackerEntry]
    let dailyGoalMl: Int

    var totalMl: Int {
        entries.reduce(0) { $0 + $1.amountMl }
    }

    var goalProgress: Double {
        min(Double(totalMl) / Double(dailyGoalMl), 1.0)
    }

    /// A day is "active" (counts toward streak) when intake reaches 80% of goal.
    var isStreakActive: Bool {
        Double(totalMl) >= Double(dailyGoalMl) * HydrationTrackerConstants.streakThresholdPercent
    }

    var caffeinatedMl: Int {
        entries.filter { $0.effectivelyCaffeinated }.reduce(0) { $0 + $1.amountMl }
    }

    var caffeineRatio: Double {
        guard totalMl > 0 else { return 0 }
        return Double(caffeinatedMl) / Double(totalMl)
    }

    var beverageTotals: [BeverageType: Int] {
        var result = [BeverageType: Int]()
        for entry in entries {
            result[entry.beverageType, default: 0] += entry.amountMl
        }
        return result
    }

    /// 24-element array; index = hour, value = ml consumed in that hour.
    var hourlyDistribution: [Int] {
        var buckets = [Int](repeating: 0, count: 24)
        let cal = Calendar.current
        for entry in entries {
            let hour = cal.component(.hour, from: entry.timeConsumed)
            buckets[hour] += entry.amountMl
        }
        return buckets
    }
}

// MARK: - Constants

enum HydrationTrackerConstants {
    static let defaultDailyGoalMl: Int = 2500
    /// A day counts toward a streak when intake is >= this fraction of the daily goal.
    static let streakThresholdPercent: Double = 0.8
    /// Warn user when caffeinated drinks exceed this fraction of total intake.
    static let caffeineRatioWarningThreshold: Double = 0.4
    /// Suggest raising the goal when the 14-day average exceeds goal by this multiple.
    static let goalRaiseSuggestionMultiple: Double = 1.2
    /// Suggest an easier intermediate goal when 14-day average is below this fraction.
    static let goalLowerSuggestionFraction: Double = 0.5
    /// Streak day counts that trigger milestone celebrations.
    static let streakMilestones: [Int] = [3, 7, 14, 30, 60, 100]
    /// Grace period: streak is not broken if a single day has no entries between two active days.
    static let streakGracePeriodDays: Int = 1
}