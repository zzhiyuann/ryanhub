import Foundation

// MARK: - CommuteTracker Models

enum CommuteDirection: String, Codable, CaseIterable, Identifiable {
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
        case .toWork: return "building.2.fill"
        case .fromWork: return "house.fill"
        }
    }
}

enum TransportMode: String, Codable, CaseIterable, Identifiable {
    case car
    case bus
    case train
    case subway
    case bike
    case walk
    case carpool
    case rideshare
    case scooter
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .car: return "Car"
        case .bus: return "Bus"
        case .train: return "Train"
        case .subway: return "Subway"
        case .bike: return "Bike"
        case .walk: return "Walk"
        case .carpool: return "Carpool"
        case .rideshare: return "Rideshare"
        case .scooter: return "Scooter"
        }
    }
    var icon: String {
        switch self {
        case .car: return "car.fill"
        case .bus: return "bus.fill"
        case .train: return "tram.fill"
        case .subway: return "lightrail.fill"
        case .bike: return "bicycle"
        case .walk: return "figure.walk"
        case .carpool: return "person.2.fill"
        case .rideshare: return "car.side.fill"
        case .scooter: return "scooter"
        }
    }
}

enum TrafficLevel: String, Codable, CaseIterable, Identifiable {
    case light
    case moderate
    case heavy
    case severe
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .heavy: return "Heavy"
        case .severe: return "Severe"
        }
    }
    var icon: String {
        switch self {
        case .light: return "checkmark.circle.fill"
        case .moderate: return "minus.circle.fill"
        case .heavy: return "exclamationmark.circle.fill"
        case .severe: return "xmark.octagon.fill"
        }
    }
}

struct CommuteTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var direction: CommuteDirection
    var durationMinutes: Int
    var transportMode: TransportMode
    var routeName: String
    var departureTime: Date
    var distanceMiles: Double
    var trafficLevel: TrafficLevel
    var cost: Double
    var stressRating: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(direction)")
        parts.append("\(durationMinutes)")
        parts.append("\(transportMode)")
        parts.append("\(routeName)")
        parts.append("\(departureTime)")
        parts.append("\(distanceMiles)")
        parts.append("\(trafficLevel)")
        parts.append("\(cost)")
        parts.append("\(stressRating)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
