import Foundation

// MARK: - Enums

enum ReadingStatus: String, CaseIterable, Codable, Identifiable {
    case reading
    case completed
    case paused
    case wantToRead
    case abandoned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .reading: return "Reading"
        case .completed: return "Completed"
        case .paused: return "Paused"
        case .wantToRead: return "Want to Read"
        case .abandoned: return "Abandoned"
        }
    }

    var icon: String {
        switch self {
        case .reading: return "book"
        case .completed: return "checkmark.circle.fill"
        case .paused: return "pause.circle.fill"
        case .wantToRead: return "bookmark"
        case .abandoned: return "xmark.circle"
        }
    }
}

enum BookGenre: String, CaseIterable, Codable, Identifiable {
    case fiction
    case nonFiction
    case scienceFiction
    case fantasy
    case mystery
    case biography
    case selfHelp
    case history
    case science
    case philosophy
    case business
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiction: return "Fiction"
        case .nonFiction: return "Non-Fiction"
        case .scienceFiction: return "Sci-Fi"
        case .fantasy: return "Fantasy"
        case .mystery: return "Mystery"
        case .biography: return "Biography"
        case .selfHelp: return "Self-Help"
        case .history: return "History"
        case .science: return "Science"
        case .philosophy: return "Philosophy"
        case .business: return "Business"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .fiction: return "text.book.closed"
        case .nonFiction: return "doc.text"
        case .scienceFiction: return "sparkles"
        case .fantasy: return "wand.and.stars"
        case .mystery: return "magnifyingglass"
        case .biography: return "person.fill"
        case .selfHelp: return "lightbulb"
        case .history: return "clock.arrow.circlepath"
        case .science: return "atom"
        case .philosophy: return "brain"
        case .business: return "briefcase.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Entry

struct ReadingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var bookTitle: String = ""
    var author: String = ""
    var pagesRead: Int = 0
    var currentPage: Int = 0
    var totalPages: Int = 0
    var readingMinutes: Int = 0
    var status: ReadingStatus = .reading
    var genre: BookGenre = .fiction
    var rating: Double = 0.0
    var notes: String = ""

    // MARK: Computed

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let parsed = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: parsed)
    }

    var dateOnly: String {
        String(date.prefix(10))
    }

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var summaryLine: String {
        var parts: [String] = []
        if !bookTitle.isEmpty { parts.append(bookTitle) }
        if pagesRead > 0 { parts.append("\(pagesRead) pages") }
        if readingMinutes > 0 { parts.append("\(readingMinutes) min") }
        return parts.joined(separator: " · ")
    }

    var progressPercent: Double {
        guard totalPages > 0 else { return 0 }
        return min(1.0, Double(currentPage) / Double(totalPages))
    }

    var progressDisplay: String {
        guard totalPages > 0 else { return "" }
        let pct = Int(progressPercent * 100)
        return "\(currentPage)/\(totalPages) (\(pct)%)"
    }

    var hasRating: Bool {
        rating >= 1.0
    }

    var ratingDisplay: String {
        guard hasRating else { return "Unrated" }
        return String(format: "%.1f★", rating)
    }

    var readingSpeedPagesPerMinute: Double? {
        guard readingMinutes > 0, pagesRead > 0 else { return nil }
        return Double(pagesRead) / Double(readingMinutes)
    }

    var isSessionEntry: Bool {
        pagesRead > 0 || readingMinutes > 0
    }
}

// MARK: - Domain Constants

enum ReadingTrackerConstants {
    static let defaultDailyPageGoal = 30
    static let defaultYearlyBookGoal = 24
    static let streakMilestones: [Int] = [7, 14, 30, 60, 100, 365]
}

// MARK: - Book Progress Summary

struct ReadingBookProgress: Identifiable {
    let id: String
    let title: String
    let author: String
    let currentPage: Int
    let totalPages: Int
    let progressPercent: Double
    let genre: BookGenre
    let lastSessionDate: Date?

    var pagesRemaining: Int {
        max(0, totalPages - currentPage)
    }
}