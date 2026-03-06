import Foundation

// MARK: - Reading Status

enum ReadingStatus: String, CaseIterable, Codable, Identifiable {
    case wantToRead
    case reading
    case finished
    case abandoned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wantToRead: return "Want to Read"
        case .reading: return "Reading"
        case .finished: return "Finished"
        case .abandoned: return "Abandoned"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead: return "star"
        case .reading: return "book.fill"
        case .finished: return "checkmark.circle.fill"
        case .abandoned: return "xmark.circle"
        }
    }
}

// MARK: - Book Genre

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
        case .biography: return "person.text.rectangle"
        case .selfHelp: return "lightbulb"
        case .history: return "clock.arrow.circlepath"
        case .science: return "atom"
        case .philosophy: return "brain.head.profile"
        case .other: return "ellipsis.circle"
        }
    }
}

// MARK: - Reading Tracker Entry

struct ReadingTrackerEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var title: String
    var author: String
    var totalPages: Int
    var currentPage: Int
    var status: ReadingStatus
    var genre: BookGenre
    var rating: Int
    var notes: String
    var startedReading: Date
    var finishedReading: Date?
    var lastReadDate: Date

    // MARK: - Formatted Date

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: parsedDate)
    }

    var parsedDate: Date {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date) ?? Date()
    }

    // MARK: - Summary

    var summaryLine: String {
        switch status {
        case .wantToRead:
            return "\(title) by \(author) — Want to Read"
        case .reading:
            return "\(title) — \(currentPage)/\(totalPages) pages (\(progressPercentFormatted))"
        case .finished:
            let stars = rating > 0 ? " — \(String(repeating: "★", count: rating))" : ""
            return "\(title) by \(author) — Finished\(stars)"
        case .abandoned:
            return "\(title) by \(author) — Abandoned at page \(currentPage)"
        }
    }

    // MARK: - Progress

    var progressFraction: Double {
        guard totalPages > 0 else { return 0 }
        return min(max(Double(currentPage) / Double(totalPages), 0), 1.0)
    }

    var progressPercent: Double {
        return progressFraction * 100.0
    }

    var progressPercentFormatted: String {
        return "\(Int(progressPercent))%"
    }

    var pagesRemaining: Int {
        return max(totalPages - currentPage, 0)
    }

    var isComplete: Bool {
        return currentPage >= totalPages
    }

    // MARK: - Reading Duration

    var formattedStartDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: startedReading)
    }

    var formattedFinishDate: String? {
        guard let finished = finishedReading else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: finished)
    }

    var daysReading: Int {
        let endDate = finishedReading ?? Date()
        let components = Calendar.current.dateComponents([.day], from: startedReading, to: endDate)
        return max(components.day ?? 0, 1)
    }

    var formattedLastRead: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastReadDate, relativeTo: Date())
    }

    // MARK: - Display Helpers

    var pageProgressDescription: String {
        return "\(currentPage) of \(totalPages) pages"
    }

    var ratingStars: String {
        guard rating > 0 else { return "" }
        let filled = String(repeating: "★", count: rating)
        let empty = String(repeating: "☆", count: max(5 - rating, 0))
        return filled + empty
    }

    var genreColorIndex: Int {
        return BookGenre.allCases.firstIndex(of: genre) ?? 0
    }
}

// MARK: - Factory Methods

extension ReadingTrackerEntry {
    static func newBook(title: String = "", author: String = "", totalPages: Int = 300) -> ReadingTrackerEntry {
        ReadingTrackerEntry(
            title: title,
            author: author,
            totalPages: totalPages,
            currentPage: 0,
            status: .wantToRead,
            genre: .fiction,
            rating: 0,
            notes: "",
            startedReading: Date(),
            finishedReading: nil,
            lastReadDate: Date()
        )
    }

    static func startReading(title: String, author: String, totalPages: Int, genre: BookGenre = .fiction) -> ReadingTrackerEntry {
        ReadingTrackerEntry(
            title: title,
            author: author,
            totalPages: totalPages,
            currentPage: 0,
            status: .reading,
            genre: genre,
            rating: 0,
            notes: "",
            startedReading: Date(),
            finishedReading: nil,
            lastReadDate: Date()
        )
    }
}