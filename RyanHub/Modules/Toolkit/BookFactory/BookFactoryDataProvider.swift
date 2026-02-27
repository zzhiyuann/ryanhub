import Foundation

// MARK: - Book Factory Data Provider

/// Provides book library data for chat context injection.
/// Uses a static cache populated by BookFactoryViewModel after loading.
enum BookFactoryDataProvider: ToolkitDataProvider {

    static let toolkitId = "bookfactory"
    static let displayName = "Book Library Data"

    static let relevanceKeywords: [String] = [
        "book", "reading", "library", "audiobook", "books", "read",
        // Chinese
        "书", "阅读", "听书", "图书"
    ]

    /// Cache populated by BookFactoryViewModel after it loads books.
    @MainActor static var cachedBooks: [BookSnapshot] = []

    /// Lightweight snapshot of a Book for context injection.
    struct BookSnapshot {
        let title: String
        let topic: String?
        let date: String
        let wordCount: Int
        let hasAudio: Bool
        let audioDuration: Double?
    }

    static func buildContextSummary() -> String? {
        let books = MainActor.assumeIsolated { cachedBooks }
        guard !books.isEmpty else { return nil }

        var lines: [String] = ["[\(displayName)]"]

        lines.append("Library: \(books.count) books")

        // Audio stats
        let audioBooks = books.filter(\.hasAudio)
        if !audioBooks.isEmpty {
            let totalDuration = audioBooks.compactMap(\.audioDuration).reduce(0, +)
            let hours = Int(totalDuration / 3600)
            let minutes = Int(totalDuration.truncatingRemainder(dividingBy: 3600) / 60)
            lines.append("Audiobooks: \(audioBooks.count) (\(hours)h \(minutes)m total)")
        }

        // Recent 5 books
        let recent = books.prefix(5)
        lines.append("Recent books:")
        for book in recent {
            var desc = "- \(book.title)"
            if let topic = book.topic {
                desc += " [\(topic)]"
            }
            desc += " (\(book.date))"
            if book.hasAudio {
                desc += " [audio]"
            }
            lines.append(desc)
        }

        if books.count > 5 {
            lines.append("(\(books.count - 5) more books)")
        }

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
