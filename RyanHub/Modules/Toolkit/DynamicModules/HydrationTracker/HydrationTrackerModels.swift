import Foundation

// MARK: - Enums

enum ContainerType: String, CaseIterable, Codable, Identifiable {
    case smallGlass
    case mediumGlass
    case largeGlass
    case bottle
    case largeBottle
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .smallGlass:  return "Small Glass (8 oz)"
        case .mediumGlass: return "Medium Glass (12 oz)"
        case .largeGlass:  return "Large Glass (16 oz)"
        case .bottle:      return "Bottle (24 oz)"
        case .largeBottle: return "Large Bottle (32 oz)"
        case .custom:      return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .smallGlass:  return "cup.and.saucer.fill"
        case .mediumGlass: return "cup.and.saucer.fill"
        case .largeGlass:  return "mug.fill"
        case .bottle:      return "waterbottle.fill"
        case .largeBottle: return "waterbottle.fill"
        case .custom:      return "slider.horizontal.3"
        }
    }

    var defaultOz: Double {
        switch self {
        case .smallGlass:  return 8
        case .mediumGlass: return 12
        case .largeGlass:  return 16
        case .bottle:      return 24
        case .largeBottle: return 32
        case .custom:      return 8
        }
    }
}

enum BeverageType: String, CaseIterable, Codable, Identifiable {
    case water
    case sparklingWater
    case tea
    case coffee
    case juice
    case milk
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
        case .sportsDrink:   return "Sports Drink"
        case .other:         return "Other"
        }
    }

    var icon: String {
        switch self {
        case .water:         return "drop.fill"
        case .sparklingWater: return "bubbles.and.sparkles.fill"
        case .tea:           return "leaf.fill"
        case .coffee:        return "cup.and.saucer.fill"
        case .juice:         return "carrot.fill"
        case .milk:          return "drop.halffull"
        case .sportsDrink:   return "bolt.fill"
        case .other:         return "ellipsis.circle.fill"
        }
    }

    /// Multiplier applied to raw oz to compute effective hydration contribution.
    var hydrationCoefficient: Double {
        switch self {
        case .water:         return 1.0
        case .sparklingWater: return 1.0
        case .tea:           return 0.95
        case .coffee:        return 0.80
        case .juice:         return 0.85
        case .milk:          return 0.90
        case .sportsDrink:   return 1.0
        case .other:         return 0.90
        }
    }

    var coefficientLabel: String {
        let pct = Int(hydrationCoefficient * 100)
        return "\(pct)% hydration"
    }
}

// MARK: - Entry

struct HydrationTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var amountOz: Double = 8.0
    var containerType: ContainerType = .smallGlass
    var beverageType: BeverageType = .water
    var note: String = ""

    // MARK: Computed — display

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return "" }
        let out = DateFormatter()
        out.timeStyle = .short
        return out.string(from: d)
    }

    var summaryLine: String {
        let oz = String(format: "%.0f oz", amountOz)
        return "\(beverageType.displayName) · \(oz) · \(containerType.displayName)"
    }

    /// Effective hydration contribution after applying beverage coefficient.
    var effectiveOz: Double {
        amountOz * beverageType.hydrationCoefficient
    }

    /// Human-readable effective oz, e.g. "14.4 oz effective".
    var formattedEffectiveOz: String {
        if effectiveOz == amountOz {
            return String(format: "%.0f oz", amountOz)
        }
        return String(format: "%.1f oz effective", effectiveOz)
    }

    /// Calendar day string "yyyy-MM-dd" extracted from the stored date field.
    var dayKey: String {
        String(date.prefix(10))
    }

    /// Hour (0–23) extracted from the stored date field.
    var hour: Int {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return 0 }
        return Calendar.current.component(.hour, from: d)
    }

    /// Resolved Date value. Returns nil if the stored string cannot be parsed.
    var resolvedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }
}

// MARK: - Insight

enum HydrationInsightKind: String, Codable {
    case streakMilestone
    case dehydrationWarning
    case bestDay
    case morningHydration
    case weeklyImprovement
    case weeklyDecline
    case beverageDiversity
    case timeGapAlert
    case goalConsistency
}

struct HydrationInsight: Identifiable, Codable {
    var id: String = UUID().uuidString
    let kind: HydrationInsightKind
    let title: String
    let message: String
    let icon: String
    /// Semantic color name: "primary", "green", "yellow", "red"
    let accentColor: String

    static func streakMilestone(streak: Int) -> HydrationInsight {
        HydrationInsight(
            kind: .streakMilestone,
            title: "\(streak)-Day Streak!",
            message: "You've hit your hydration goal \(streak) days in a row. Keep it up!",
            icon: "flame.fill",
            accentColor: "yellow"
        )
    }

    static func dehydrationWarning(remainingOz: Double) -> HydrationInsight {
        HydrationInsight(
            kind: .dehydrationWarning,
            title: "Hydration Check",
            message: String(format: "It's past 2pm and you still need %.0f oz to reach your goal. Time to drink up!", remainingOz),
            icon: "exclamationmark.triangle.fill",
            accentColor: "red"
        )
    }

    static func bestDay(dayName: String) -> HydrationInsight {
        HydrationInsight(
            kind: .bestDay,
            title: "Best Day: \(dayName)",
            message: "\(dayName) is your strongest hydration day. Try to carry that habit to the whole week.",
            icon: "star.fill",
            accentColor: "primary"
        )
    }

    static func morningHydration() -> HydrationInsight {
        HydrationInsight(
            kind: .morningHydration,
            title: "Front-load Your Hydration",
            message: "Your average morning intake (before 10am) is below 16 oz. Starting hydrated boosts focus and energy.",
            icon: "sunrise.fill",
            accentColor: "yellow"
        )
    }

    static func weeklyImprovement(percent: Double) -> HydrationInsight {
        HydrationInsight(
            kind: .weeklyImprovement,
            title: "Great Progress!",
            message: String(format: "Your hydration is up %.0f%% this week compared to last. Outstanding consistency!", percent),
            icon: "arrow.up.circle.fill",
            accentColor: "green"
        )
    }

    static func weeklyDecline(percent: Double) -> HydrationInsight {
        HydrationInsight(
            kind: .weeklyDecline,
            title: "Hydration Dipped",
            message: String(format: "Your intake dropped %.0f%% this week. Try setting a reminder to drink every 2 hours.", abs(percent)),
            icon: "arrow.down.circle.fill",
            accentColor: "red"
        )
    }

    static func beverageDiversity(dominantType: BeverageType) -> HydrationInsight {
        HydrationInsight(
            kind: .beverageDiversity,
            title: "Diversify Your Intake",
            message: "Over 80% of your intake is \(dominantType.displayName). Try mixing in herbal tea or sparkling water for variety.",
            icon: "sparkles",
            accentColor: "primary"
        )
    }

    static func timeGapAlert(hours: Int) -> HydrationInsight {
        HydrationInsight(
            kind: .timeGapAlert,
            title: "Time to Drink",
            message: "You haven't had anything to drink in \(hours) hour\(hours == 1 ? "" : "s"). Even a small glass helps!",
            icon: "clock.fill",
            accentColor: "yellow"
        )
    }

    static func goalConsistency(rate: Double, currentGoal: Double) -> HydrationInsight {
        HydrationInsight(
            kind: .goalConsistency,
            title: "Ready for a Bigger Goal?",
            message: String(format: "You've hit your %.0f oz goal %.0f%% of days this month. Consider increasing your goal by 8 oz!", currentGoal, rate * 100),
            icon: "trophy.fill",
            accentColor: "green"
        )
    }
}

// MARK: - Daily Summary (helper for ViewModel / HistoryView)

struct HydrationDaySummary: Identifiable {
    var id: String { dayKey }
    let dayKey: String
    let entries: [HydrationTrackerEntry]
    let dailyGoalOz: Double

    var totalRawOz: Double {
        entries.reduce(0) { $0 + $1.amountOz }
    }

    var totalEffectiveOz: Double {
        entries.reduce(0) { $0 + $1.effectiveOz }
    }

    var goalProgress: Double {
        min(1.0, totalEffectiveOz / max(1, dailyGoalOz))
    }

    var goalMet: Bool {
        totalEffectiveOz >= dailyGoalOz
    }

    /// Fraction 0–1, used to drive calendar heatmap color (red → yellow → green).
    var heatmapIntensity: Double {
        goalProgress
    }

    var date: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: dayKey)
    }

    var formattedDayKey: String {
        guard let d = date else { return dayKey }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: d)
    }
}