import Foundation

// MARK: - PeopleJournal Models

enum RelationshipType: String, Codable, CaseIterable, Identifiable {
    case colleague
    case friend
    case acquaintance
    case client
    case mentor
    case family
    case neighbor
    case classmate
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .colleague: return "Colleague"
        case .friend: return "Friend"
        case .acquaintance: return "Acquaintance"
        case .client: return "Client"
        case .mentor: return "Mentor"
        case .family: return "Family"
        case .neighbor: return "Neighbor"
        case .classmate: return "Classmate"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .colleague: return "briefcase.fill"
        case .friend: return "face.smiling"
        case .acquaintance: return "person.fill"
        case .client: return "building.2.fill"
        case .mentor: return "graduationcap.fill"
        case .family: return "house.fill"
        case .neighbor: return "door.left.hand.open"
        case .classmate: return "book.fill"
        case .other: return "person.crop.circle.badge.questionmark"
        }
    }
}

enum MeetingContext: String, Codable, CaseIterable, Identifiable {
    case coffee
    case work
    case event
    case online
    case phone
    case random
    case introduction
    case classroom
    case gym
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .coffee: return "Coffee / Meal"
        case .work: return "Work Meeting"
        case .event: return "Event / Party"
        case .online: return "Online / Video"
        case .phone: return "Phone Call"
        case .random: return "Random Encounter"
        case .introduction: return "Introduction"
        case .classroom: return "Class / Workshop"
        case .gym: return "Gym / Sports"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .coffee: return "cup.and.saucer.fill"
        case .work: return "desktopcomputer"
        case .event: return "party.popper"
        case .online: return "video.fill"
        case .phone: return "phone.fill"
        case .random: return "figure.walk"
        case .introduction: return "hand.wave.fill"
        case .classroom: return "studentdesk"
        case .gym: return "figure.run"
        case .other: return "ellipsis.circle"
        }
    }
}

enum InteractionMood: String, Codable, CaseIterable, Identifiable {
    case great
    case positive
    case neutral
    case awkward
    case tense
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .great: return "Great"
        case .positive: return "Positive"
        case .neutral: return "Neutral"
        case .awkward: return "Awkward"
        case .tense: return "Tense"
        }
    }
    var icon: String {
        switch self {
        case .great: return "star.fill"
        case .positive: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle"
        case .awkward: return "face.dashed"
        case .tense: return "exclamationmark.triangle"
        }
    }
}

struct PeopleJournalEntry: Codable, Identifiable {
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
    var connectionStrength: Int
    var interactionMood: InteractionMood
    var followUpNeeded: Bool
    var followUpNote: String
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(personName)")
        parts.append("\(relationship)")
        parts.append("\(meetingContext)")
        parts.append("\(location)")
        parts.append("\(topics)")
        parts.append("\(connectionStrength)")
        parts.append("\(interactionMood)")
        parts.append("\(followUpNeeded)")
        parts.append("\(followUpNote)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
