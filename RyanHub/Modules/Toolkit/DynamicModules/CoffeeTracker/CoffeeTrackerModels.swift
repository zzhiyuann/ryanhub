import Foundation

// MARK: - CoffeeTracker Models

enum CoffeeDrinkType: String, Codable, CaseIterable, Identifiable {
    case espresso
    case drip
    case latte
    case cappuccino
    case americano
    case coldBrew
    case pourOver
    case mocha
    case macchiato
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .espresso: return "Espresso"
        case .drip: return "Drip Coffee"
        case .latte: return "Latte"
        case .cappuccino: return "Cappuccino"
        case .americano: return "Americano"
        case .coldBrew: return "Cold Brew"
        case .pourOver: return "Pour Over"
        case .mocha: return "Mocha"
        case .macchiato: return "Macchiato"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .espresso: return "drop.fill"
        case .drip: return "mug.fill"
        case .latte: return "cup.and.saucer.fill"
        case .cappuccino: return "cup.and.saucer.fill"
        case .americano: return "drop.triangle.fill"
        case .coldBrew: return "snowflake"
        case .pourOver: return "arrow.down.to.line"
        case .mocha: return "leaf.fill"
        case .macchiato: return "drop.halffull"
        case .other: return "ellipsis.circle.fill"
        }
    }

    // Default caffeine (mg) per cup size: [small, medium, large, extraLarge]
    var caffeineDefaults: [CoffeeCupSize: Int] {
        switch self {
        case .espresso:    return [.small: 63, .medium: 63,  .large: 126, .extraLarge: 126]
        case .drip:        return [.small: 95, .medium: 145, .large: 195, .extraLarge: 235]
        case .latte:       return [.small: 63, .medium: 63,  .large: 126, .extraLarge: 126]
        case .cappuccino:  return [.small: 63, .medium: 63,  .large: 126, .extraLarge: 126]
        case .americano:   return [.small: 63, .medium: 95,  .large: 126, .extraLarge: 126]
        case .coldBrew:    return [.small: 100, .medium: 150, .large: 200, .extraLarge: 260]
        case .pourOver:    return [.small: 95, .medium: 145, .large: 195, .extraLarge: 235]
        case .mocha:       return [.small: 63, .medium: 95,  .large: 126, .extraLarge: 126]
        case .macchiato:   return [.small: 63, .medium: 63,  .large: 126, .extraLarge: 126]
        case .other:       return [.small: 80, .medium: 120, .large: 160, .extraLarge: 200]
        }
    }

    func defaultCaffeine(for size: CoffeeCupSize) -> Int {
        caffeineDefaults[size] ?? 80
    }
}

enum CoffeeCupSize: String, Codable, CaseIterable, Identifiable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small:      return "Small (8oz)"
        case .medium:     return "Medium (12oz)"
        case .large:      return "Large (16oz)"
        case .extraLarge: return "XL (20oz)"
        }
    }

    var icon: String {
        switch self {
        case .small:      return "s.circle.fill"
        case .medium:     return "m.circle.fill"
        case .large:      return "l.circle.fill"
        case .extraLarge: return "xmark.circle.fill"
        }
    }

    var ounces: Int {
        switch self {
        case .small:      return 8
        case .medium:     return 12
        case .large:      return 16
        case .extraLarge: return 20
        }
    }
}

// MARK: - Entry

struct CoffeeTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var drinkType: CoffeeDrinkType
    var cupSize: CoffeeCupSize
    var caffeineMg: Int
    var time: Date
    var isDecaf: Bool
    var notes: String

    // MARK: Computed

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        guard let d = parsedDate else { return date }
        return f.string(from: d)
    }

    var formattedTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: time)
    }

    var dayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: time)
    }

    /// Effective caffeine contributed to system (0 if decaf)
    var effectiveCaffeineMg: Int {
        isDecaf ? 0 : caffeineMg
    }

    /// Caffeine still active in body at a given reference time, using 5-hour half-life
    func caffeineRemaining(at referenceDate: Date = Date()) -> Double {
        guard !isDecaf else { return 0 }
        let hoursElapsed = referenceDate.timeIntervalSince(time) / 3600.0
        guard hoursElapsed >= 0 else { return Double(caffeineMg) }
        return Double(caffeineMg) * pow(0.5, hoursElapsed / 5.0)
    }

    /// True if the entry's time is at or after 14:00 (2 PM)
    var isAfterAfternoonCutoff: Bool {
        let components = Calendar.current.dateComponents([.hour], from: time)
        return (components.hour ?? 0) >= 14
    }

    /// Hour of day (0–23) when this entry was logged
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: time)
    }

    var summaryLine: String {
        let caffeineText = isDecaf ? "Decaf" : "\(effectiveCaffeineMg)mg"
        return "\(drinkType.displayName) · \(cupSize.displayName) · \(caffeineText) · \(formattedTime)"
    }

    // MARK: Private helpers

    private var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }
}

// MARK: - Daily Summary Helper

struct CoffeeTrackerDaySummary {
    let dayKey: String          // "yyyy-MM-dd"
    let entries: [CoffeeTrackerEntry]

    var totalCaffeineMg: Int {
        entries.reduce(0) { $0 + $1.effectiveCaffeineMg }
    }

    var cupCount: Int { entries.count }

    var isWithinGoal: Bool {
        totalCaffeineMg <= CoffeeTrackerConstants.dailyGoalMg
    }
}

// MARK: - Constants

enum CoffeeTrackerConstants {
    static let dailyGoalMg = 400
    static let halfLifeHours: Double = 5.0
    static let afternoonCutoffHour = 14   // 2 PM
    static let bedtimeHour = 22           // 10 PM
    /// At bedtime (8h after 2 PM cutoff), fraction of caffeine still active: pow(0.5, 8/5) ≈ 0.33
    static let afternoonRetentionAtBedtime: Double = pow(0.5, Double(bedtimeHour - afternoonCutoffHour) / halfLifeHours)
}