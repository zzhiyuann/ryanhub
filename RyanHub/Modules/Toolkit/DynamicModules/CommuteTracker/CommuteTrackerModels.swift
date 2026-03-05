import Foundation

// MARK: - Enums

enum CommuteDirection: String, CaseIterable, Codable, Identifiable {
    case toWork
    case fromWork

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toWork: return "To Work"
        case .fromWork: return "From Work"
        }
    }

    var icon: String {
        switch self {
        case .toWork: return "building.2"
        case .fromWork: return "house.fill"
        }
    }
}

enum TransportMode: String, CaseIterable, Codable, Identifiable {
    case driving
    case publicTransit
    case cycling
    case walking
    case carpool
    case rideshare
    case train

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .driving: return "Driving"
        case .publicTransit: return "Public Transit"
        case .cycling: return "Cycling"
        case .walking: return "Walking"
        case .carpool: return "Carpool"
        case .rideshare: return "Rideshare"
        case .train: return "Train"
        }
    }

    var icon: String {
        switch self {
        case .driving: return "car.fill"
        case .publicTransit: return "bus.fill"
        case .cycling: return "bicycle"
        case .walking: return "figure.walk"
        case .carpool: return "person.2.fill"
        case .rideshare: return "car.side.fill"
        case .train: return "tram.fill"
        }
    }
}

// MARK: - Entry

struct CommuteTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var durationMinutes: Int = 30
    var direction: CommuteDirection = .toWork
    var transportMode: TransportMode = .driving
    var routeName: String = ""
    var departureTime: Date = Date()
    var trafficLevel: Int = 3
    var costCents: Int = 0
    var delayMinutes: Int = 0
    var experienceRating: Int = 3
    var notes: String = ""

    // MARK: - Computed: Formatted Date

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateOnly: String {
        String(date.prefix(10))
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    // MARK: - Computed: Display

    var summaryLine: String {
        let dir = direction.displayName
        let mode = transportMode.displayName
        let route = routeName.isEmpty ? "" : " via \(routeName)"
        return "\(dir) · \(durationMinutes) min · \(mode)\(route)"
    }

    var formattedDuration: String {
        if durationMinutes >= 60 {
            let h = durationMinutes / 60
            let m = durationMinutes % 60
            return m == 0 ? "\(h)h" : "\(h)h \(m)m"
        }
        return "\(durationMinutes) min"
    }

    var formattedCost: String {
        if costCents == 0 { return "Free" }
        let dollars = Double(costCents) / 100.0
        return String(format: "$%.2f", dollars)
    }

    var costDollars: Double {
        Double(costCents) / 100.0
    }

    var trafficEmoji: String {
        switch trafficLevel {
        case 1: return "😊"
        case 2: return "🙂"
        case 3: return "😐"
        case 4: return "😟"
        case 5: return "😠"
        default: return "😐"
        }
    }

    var trafficLabel: String {
        switch trafficLevel {
        case 1: return "Clear"
        case 2: return "Light"
        case 3: return "Moderate"
        case 4: return "Heavy"
        case 5: return "Gridlock"
        default: return "Moderate"
        }
    }

    var experienceLabel: String {
        switch experienceRating {
        case 1: return "Terrible"
        case 2: return "Poor"
        case 3: return "Okay"
        case 4: return "Good"
        case 5: return "Great"
        default: return "Okay"
        }
    }

    var formattedDepartureTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: departureTime)
    }

    var departureHour: Double {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: departureTime)
        let minute = cal.component(.minute, from: departureTime)
        return Double(hour) + Double(minute) / 60.0
    }

    var hasDelay: Bool { delayMinutes > 0 }

    var effectiveDurationMinutes: Int { durationMinutes }

    var weekdayName: String {
        guard let d = parsedDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f.string(from: d)
    }

    var weekdayShort: String {
        guard let d = parsedDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f.string(from: d)
    }
}

// MARK: - Goal Configuration

struct CommuteGoalConfig: Codable {
    var dailyTargetMinutes: Int = 60

    var progressColor: String {
        // Used by views to pick hubAccentGreen / hubAccentYellow / hubAccentRed
        return "dynamic"
    }
}

// MARK: - Route Summary (used by routeRankings)

struct CommuteRouteSummary: Identifiable {
    var id: String { routeName }
    let routeName: String
    let avgMinutes: Double
    let tripCount: Int

    var formattedAvg: String {
        String(format: "%.0f min", avgMinutes)
    }
}

// MARK: - Day-of-Week ordering helper

extension String {
    static let orderedWeekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    var weekdayOrder: Int {
        String.orderedWeekdays.firstIndex(of: self) ?? 99
    }
}