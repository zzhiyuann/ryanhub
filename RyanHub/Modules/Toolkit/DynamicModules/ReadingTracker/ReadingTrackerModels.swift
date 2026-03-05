import Foundation

// MARK: - ReadingTracker Models

enum ReadingStatus: String, Codable, CaseIterable, Identifiable {
    case wantToRead
    case currentlyReading
    case finished
    case abandoned
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .finished: return "Finished"
        case .abandoned: return "Abandoned"
        }
    }
    var icon: String {
        switch self {
        case .wantToRead: return "bookmark"
        case .currentlyReading: return "book.fill"
        case .finished: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

enum BookGenre: String, Codable, CaseIterable, Identifiable {
    case fiction
    case nonFiction
    case sciFi
    case fantasy
    case mystery
    case biography
    case selfHelp
    case history
    case science
    case business
    case philosophy
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .fiction: return "Fiction"
        case .nonFiction: return "Non-Fiction"
        case .sciFi: return "Sci-Fi"
        case .fantasy: return "Fantasy"
        case .mystery: return "Mystery"
        case .biography: return "Biography"
        case .selfHelp: return "Self-Help"
        case .history: return "History"
        case .science: return "Science"
        case .business: return "Business"
        case .philosophy: return "Philosophy"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .fiction: return "text.book.closed"
        case .nonFiction: return "newspaper"
        case .sciFi: return "sparkles"
        case .fantasy: return "wand.and.stars"
        case .mystery: return "magnifyingglass"
        case .biography: return "person.text.rectangle"
        case .selfHelp: return "lightbulb"
        case .history: return "clock.arrow.circlepath"
        case .science: return "atom"
        case .business: return "chart.line.uptrend.xyaxis"
        case .philosophy: return "brain.head.profile"
        case .other: return "ellipsis.circle"
        }
    }
}

struct ReadingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var bookTitle: String
    var author: String
    var genre: BookGenre
    var status: ReadingStatus
    var totalPages: Int
    var currentPage: Int
    var minutesRead: Int
    var rating: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(bookTitle)")
        parts.append("\(author)")
        parts.append("\(genre)")
        parts.append("\(status)")
        parts.append("\(totalPages)")
        parts.append("\(currentPage)")
        parts.append("\(minutesRead)")
        parts.append("\(rating)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
