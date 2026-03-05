import Foundation

// MARK: - Enums

enum ReadingStatus: String, CaseIterable, Codable, Identifiable {
    case wantToRead = "wantToRead"
    case currentlyReading = "currentlyReading"
    case finished = "finished"
    case paused = "paused"
    case abandoned = "abandoned"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .wantToRead:       return "Want to Read"
        case .currentlyReading: return "Currently Reading"
        case .finished:         return "Finished"
        case .paused:           return "Paused"
        case .abandoned:        return "Abandoned"
        }
    }

    var icon: String {
        switch self {
        case .wantToRead:       return "bookmark"
        case .currentlyReading: return "book.fill"
        case .finished:         return "checkmark.circle.fill"
        case .paused:           return "pause.circle.fill"
        case .abandoned:        return "xmark.circle"
        }
    }
}

enum BookGenre: String, CaseIterable, Codable, Identifiable {
    case fiction    = "fiction"
    case nonFiction = "nonFiction"
    case sciFi      = "sciFi"
    case fantasy    = "fantasy"
    case mystery    = "mystery"
    case biography  = "biography"
    case selfHelp   = "selfHelp"
    case history    = "history"
    case science    = "science"
    case philosophy = "philosophy"
    case business   = "business"
    case other      = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiction:    return "Fiction"
        case .nonFiction: return "Non-Fiction"
        case .sciFi:      return "Sci-Fi"
        case .fantasy:    return "Fantasy"
        case .mystery:    return "Mystery"
        case .biography:  return "Biography"
        case .selfHelp:   return "Self-Help"
        case .history:    return "History"
        case .science:    return "Science"
        case .philosophy: return "Philosophy"
        case .business:   return "Business"
        case .other:      return "Other"
        }
    }

    var icon: String {
        switch self {
        case .fiction:    return "text.book.closed.fill"
        case .nonFiction: return "doc.text.fill"
        case .sciFi:      return "sparkles"
        case .fantasy:    return "wand.and.stars"
        case .mystery:    return "magnifyingglass"
        case .biography:  return "person.fill"
        case .selfHelp:   return "lightbulb.fill"
        case .history:    return "clock.fill"
        case .science:    return "atom"
        case .philosophy: return "brain.head.profile"
        case .business:   return "briefcase.fill"
        case .other:      return "ellipsis.circle.fill"
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

    // Data fields
    var bookTitle: String = ""
    var author: String = ""
    var totalPages: Int = 0
    var currentPage: Int = 0
    var pagesRead: Int = 0
    var minutesRead: Int = 0
    var status: ReadingStatus = .currentlyReading
    var genre: BookGenre = .fiction
    var rating: Double = 0.0
    var notes: String = ""

    // MARK: Computed — display

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateOnly: String { String(date.prefix(10)) }

    var summaryLine: String {
        var parts: [String] = []
        if !bookTitle.isEmpty { parts.append(bookTitle) }
        if pagesRead > 0 { parts.append("\(pagesRead) pages") }
        if minutesRead > 0 { parts.append("\(minutesRead) min") }
        return parts.joined(separator: " · ")
    }

    // MARK: Computed — progress

    var progressPercent: Double {
        guard totalPages > 0 else { return 0 }
        return min(Double(currentPage) / Double(totalPages), 1.0)
    }

    var progressLabel: String {
        guard totalPages > 0 else { return "–" }
        let pct = Int(progressPercent * 100)
        return "\(pct)% (\(currentPage)/\(totalPages))"
    }

    var pagesRemaining: Int {
        guard totalPages > 0 else { return 0 }
        return max(totalPages - currentPage, 0)
    }

    // MARK: Computed — reading speed

    /// Pages per hour for this session. Returns nil if data is insufficient.
    var sessionReadingSpeed: Double? {
        guard pagesRead > 0, minutesRead > 0 else { return nil }
        return Double(pagesRead) / (Double(minutesRead) / 60.0)
    }

    var formattedReadingSpeed: String {
        guard let speed = sessionReadingSpeed else { return "–" }
        return String(format: "%.0f pages/hr", speed)
    }

    // MARK: Computed — duration

    var formattedDuration: String {
        guard minutesRead > 0 else { return "–" }
        if minutesRead < 60 { return "\(minutesRead) min" }
        let h = minutesRead / 60
        let m = minutesRead % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    // MARK: Computed — rating

    var formattedRating: String {
        guard rating > 0 else { return "Not rated" }
        return String(format: "%.1f / 5.0", rating)
    }

    var ratingStars: String {
        guard rating > 0 else { return "" }
        let full = Int(rating)
        let half = rating - Double(full) >= 0.5
        var stars = String(repeating: "★", count: full)
        if half { stars += "½" }
        return stars
    }

    // MARK: Computed — validation

    var isValid: Bool {
        !bookTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var hasSessionData: Bool {
        pagesRead > 0 || minutesRead > 0
    }
}

// MARK: - Domain Constants

enum ReadingTrackerConstants {
    static let dailyPageGoal: Int = 30
    static let annualBookGoal: Int = 24
    static let minRating: Double = 0.0
    static let maxRating: Double = 5.0
    static let ratingStep: Double = 0.5
}

// MARK: - Persistence Key

extension ReadingTrackerEntry {
    static let storageKey = "readingTracker_entries"
}