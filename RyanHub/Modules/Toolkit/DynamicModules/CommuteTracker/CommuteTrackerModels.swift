import Foundation

// MARK: - Entry

struct CommuteTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var direction: CommuteDirection = .toWork
    var durationMinutes: Int = 30
    var transportMode: TransportMode = .car
    var routeLabel: RouteLabel = .primary
    var departureTime: Date = Date()
    var trafficCondition: TrafficCondition = .light
    var costCents: Int = 0
    var stressLevel: Int = 3
    var usedEcoMode: Bool = false
    var notes: String = ""

    // MARK: Computed

    var formattedDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: departureTime)
    }

    var formattedDepartureTime: String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: departureTime)
    }

    var dayOfWeek: Int {
        Calendar.current.component(.weekday, from: departureTime)
    }

    var dateKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: departureTime)
    }

    var costInDollars: Double {
        Double(costCents) / 100.0
    }

    var formattedCost: String {
        costCents == 0 ? "Free" : String(format: "$%.2f", costInDollars)
    }

    var formattedDuration: String {
        durationMinutes >= 60
            ? String(format: "%dh %dm", durationMinutes / 60, durationMinutes % 60)
            : "\(durationMinutes) min"
    }

    var isEcoFriendly: Bool {
        switch transportMode {
        case .bike, .walk, .scooter, .bus, .subway, .train: return true
        default: return false
        }
    }

    var summaryLine: String {
        "\(direction.displayName) · \(formattedDuration) · \(transportMode.displayName) · \(trafficCondition.displayName)"
    }

    var stressLabel: String {
        switch stressLevel {
        case 1...2: return "Low"
        case 3:     return "Moderate"
        case 4...5: return "High"
        default:    return "Unknown"
        }
    }

    var durationCategory: DurationCategory {
        switch durationMinutes {
        case ..<20:  return .fast
        case 20..<40: return .normal
        case 40..<60: return .slow
        default:     return .veryLow
        }
    }
}

// MARK: - DurationCategory

enum DurationCategory {
    case fast, normal, slow, veryLow

    var label: String {
        switch self {
        case .fast:   return "Fast"
        case .normal: return "Normal"
        case .slow:   return "Slow"
        case .veryLow: return "Very Slow"
        }
    }
}

// MARK: - CommuteDirection

enum CommuteDirection: String, CaseIterable, Codable, Identifiable {
    case toWork
    case fromWork

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .toWork:   return "To Work"
        case .fromWork: return "From Work"
        }
    }

    var icon: String {
        switch self {
        case .toWork:   return "arrow.right.circle"
        case .fromWork: return "arrow.left.circle"
        }
    }

    var opposite: CommuteDirection {
        self == .toWork ? .fromWork : .toWork
    }
}

// MARK: - TransportMode

enum TransportMode: String, CaseIterable, Codable, Identifiable {
    case car
    case bus
    case subway
    case train
    case bike
    case walk
    case carpool
    case rideshare
    case scooter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .car:      return "Car"
        case .bus:      return "Bus"
        case .subway:   return "Subway"
        case .train:    return "Train"
        case .bike:     return "Bike"
        case .walk:     return "Walk"
        case .carpool:  return "Carpool"
        case .rideshare: return "Rideshare"
        case .scooter:  return "Scooter"
        }
    }

    var icon: String {
        switch self {
        case .car:      return "car.fill"
        case .bus:      return "bus.fill"
        case .subway:   return "tram.fill"
        case .train:    return "train.side.front.car"
        case .bike:     return "bicycle"
        case .walk:     return "figure.walk"
        case .carpool:  return "person.2.fill"
        case .rideshare: return "car.2.fill"
        case .scooter:  return "scooter"
        }
    }

    var isEcoFriendly: Bool {
        switch self {
        case .bike, .walk, .scooter, .bus, .subway, .train: return true
        default: return false
        }
    }

    var typicalCostLevel: Int {
        switch self {
        case .walk, .bike:      return 0
        case .bus, .subway, .train: return 1
        case .scooter:          return 2
        case .carpool:          return 3
        case .rideshare:        return 4
        case .car:              return 3
        }
    }
}

// MARK: - RouteLabel

enum RouteLabel: String, CaseIterable, Codable, Identifiable {
    case primary
    case alternate1
    case alternate2
    case highway
    case scenic
    case shortcut

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .primary:   return "Primary Route"
        case .alternate1: return "Alternate 1"
        case .alternate2: return "Alternate 2"
        case .highway:   return "Highway"
        case .scenic:    return "Scenic Route"
        case .shortcut:  return "Shortcut"
        }
    }

    var icon: String {
        switch self {
        case .primary:   return "road.lanes"
        case .alternate1: return "arrow.triangle.branch"
        case .alternate2: return "arrow.triangle.swap"
        case .highway:   return "road.lanes.curved.right"
        case .scenic:    return "leaf.fill"
        case .shortcut:  return "bolt.fill"
        }
    }
}

// MARK: - TrafficCondition

enum TrafficCondition: String, CaseIterable, Codable, Identifiable {
    case clear
    case light
    case moderate
    case heavy
    case standstill

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .clear:      return "Clear"
        case .light:      return "Light"
        case .moderate:   return "Moderate"
        case .heavy:      return "Heavy"
        case .standstill: return "Standstill"
        }
    }

    var icon: String {
        switch self {
        case .clear:      return "checkmark.circle.fill"
        case .light:      return "circle.fill"
        case .moderate:   return "exclamationmark.circle"
        case .heavy:      return "exclamationmark.triangle"
        case .standstill: return "xmark.octagon.fill"
        }
    }

    var severityScore: Int {
        switch self {
        case .clear:      return 0
        case .light:      return 1
        case .moderate:   return 2
        case .heavy:      return 3
        case .standstill: return 4
        }
    }

    var colorName: String {
        switch self {
        case .clear:      return "hubAccentGreen"
        case .light:      return "hubAccentGreen"
        case .moderate:   return "hubAccentYellow"
        case .heavy:      return "hubAccentRed"
        case .standstill: return "hubAccentRed"
        }
    }
}

// MARK: - Goals & Settings

struct CommuteTrackerSettings: Codable {
    var dailyGoalMinutes: Int = 30
    var homeLocation: String = ""
    var workLocation: String = ""
    var typicalWorkDays: [Int] = [2, 3, 4, 5, 6] // Mon–Fri (Calendar.weekday)
}

// MARK: - Route Stats (ViewModel helper)

struct RouteStats: Identifiable {
    var id: String { route.rawValue }
    let route: RouteLabel
    let avgMinutes: Double
    let tripCount: Int

    var formattedAvg: String {
        String(format: "%.0f min", avgMinutes)
    }
}

// MARK: - Heatmap Cell (HistoryView helper)

struct CommuteHeatmapDay: Identifiable {
    var id: String { dateKey }
    let dateKey: String
    let date: Date
    let totalMinutes: Int
    let tripCount: Int

    var intensity: Double {
        // Normalize against a 60-min reference: 0 = no data, 1.0 = 60+ min (red), low = green
        guard tripCount > 0 else { return 0 }
        return min(Double(totalMinutes) / 60.0, 1.0)
    }
}