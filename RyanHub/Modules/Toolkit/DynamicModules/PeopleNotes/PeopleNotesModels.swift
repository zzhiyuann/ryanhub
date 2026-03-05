import Foundation

// MARK: - PeopleNotes Models

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case colleague
    case friend
    case family
    case acquaintance
    case client
    case mentor
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .colleague: return "Colleague"
        case .friend: return "Friend"
        case .family: return "Family"
        case .acquaintance: return "Acquaintance"
        case .client: return "Client"
        case .mentor: return "Mentor"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .colleague: return "briefcase"
        case .friend: return "heart"
        case .family: return "house"
        case .acquaintance: return "person.wave.2"
        case .client: return "building.2"
        case .mentor: return "graduationcap"
        case .other: return "person"
        }
    }
}

enum MeetingContext: String, Codable, CaseIterable, Identifiable {
    case inPerson
    case coffee
    case meeting
    case call
    case event
    case online
    case casual
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .inPerson: return "In Person"
        case .coffee: return "Coffee / Meal"
        case .meeting: return "Meeting"
        case .call: return "Phone / Video Call"
        case .event: return "Event / Party"
        case .online: return "Online / Chat"
        case .casual: return "Casual Encounter"
        }
    }
    var icon: String {
        switch self {
        case .inPerson: return "person.2"
        case .coffee: return "cup.and.saucer"
        case .meeting: return "person.3"
        case .call: return "phone"
        case .event: return "party.popper"
        case .online: return "message"
        case .casual: return "figure.walk"
        }
    }
}

enum InteractionMood: String, Codable, CaseIterable, Identifiable {
    case great
    case good
    case neutral
    case awkward
    case tense
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .great: return "Great"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .awkward: return "Awkward"
        case .tense: return "Tense"
        }
    }
    var icon: String {
        switch self {
        case .great: return "face.smiling"
        case .good: return "hand.thumbsup"
        case .neutral: return "minus.circle"
        case .awkward: return "questionmark.circle"
        case .tense: return "exclamationmark.triangle"
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
    var meetingContext: MeetingContext
    var location: String
    var topics: String
    var followUp: String
    var followUpDone: Bool
    var connectionRating: Int
    var interactionMood: InteractionMood
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(personName)")
        parts.append("\(relationship)")
        parts.append("\(meetingContext)")
        parts.append("\(location)")
        parts.append("\(topics)")
        parts.append("\(followUp)")
        parts.append("\(followUpDone)")
        parts.append("\(connectionRating)")
        parts.append("\(interactionMood)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
