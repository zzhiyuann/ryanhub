import Foundation

// MARK: - PeopleNotes Models

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case colleague
    case friend
    case acquaintance
    case mentor
    case client
    case classmate
    case neighbor
    case family
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .colleague: return "Colleague"
        case .friend: return "Friend"
        case .acquaintance: return "Acquaintance"
        case .mentor: return "Mentor"
        case .client: return "Client"
        case .classmate: return "Classmate"
        case .neighbor: return "Neighbor"
        case .family: return "Family"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .colleague: return "briefcase.fill"
        case .friend: return "heart.fill"
        case .acquaintance: return "hand.wave.fill"
        case .mentor: return "graduationcap.fill"
        case .client: return "building.2.fill"
        case .classmate: return "book.fill"
        case .neighbor: return "house.fill"
        case .family: return "figure.2.and.child.holdinghands"
        case .other: return "person.fill"
        }
    }
}

enum MeetingType: String, Codable, CaseIterable, Identifiable {
    case coffee
    case meeting
    case call
    case event
    case casual
    case introduced
    case classSession
    case online
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .coffee: return "Coffee / Meal"
        case .meeting: return "Meeting"
        case .call: return "Call / Video"
        case .event: return "Event / Party"
        case .casual: return "Casual Run-in"
        case .introduced: return "First Introduction"
        case .classSession: return "Class / Workshop"
        case .online: return "Online / DM"
        }
    }
    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .meeting: return "person.2.fill"
        case .call: return "phone.fill"
        case .event: return "party.popper.fill"
        case .casual: return "figure.walk"
        case .introduced: return "hand.raised.fill"
        case .classSession: return "studentdesk"
        case .online: return "message.fill"
        }
    }
}

enum EnergyLevel: String, Codable, CaseIterable, Identifiable {
    case inspiring
    case warm
    case neutral
    case draining
    case tense
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .inspiring: return "Inspiring"
        case .warm: return "Warm & Friendly"
        case .neutral: return "Neutral"
        case .draining: return "Draining"
        case .tense: return "Tense"
        }
    }
    var icon: String {
        switch self {
        case .inspiring: return "sparkles"
        case .warm: return "sun.max.fill"
        case .neutral: return "minus.circle.fill"
        case .draining: return "battery.25percent"
        case .tense: return "bolt.fill"
        }
    }
}

struct PeopleNotesEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var personName: String
    var relationship: RelationshipType
    var meetingType: MeetingType
    var location: String
    var topics: String
    var interactionQuality: Int
    var energyLevel: EnergyLevel
    var followUpNeeded: Bool
    var followUpNote: String
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(personName)")
        parts.append("\(relationship)")
        parts.append("\(meetingType)")
        parts.append("\(location)")
        parts.append("\(topics)")
        parts.append("\(interactionQuality)")
        parts.append("\(energyLevel)")
        parts.append("\(followUpNeeded)")
        parts.append("\(followUpNote)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
