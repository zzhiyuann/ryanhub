import Foundation

// MARK: - Fluent Data Provider

/// Provides vocabulary and study data for chat context injection.
/// Reads from FluentStore's JSON files for a standalone summary.
enum FluentDataProvider: ToolkitDataProvider {

    static let toolkitId = "fluent"
    static let displayName = "Fluent Vocabulary Data"

    static let relevanceKeywords: [String] = [
        "vocab", "vocabulary", "word", "flashcard", "review", "study",
        "streak", "fluent", "flashcards", "cards", "studied",
        // Chinese
        "词汇", "单词", "复习", "学习", "背单词", "打卡"
    ]

    static func buildContextSummary() -> String? {
        let (vocabulary, progress, todayStats, dueCardCount) = MainActor.assumeIsolated {
            let store = FluentStore.shared
            let vocab = store.loadVocabulary()
            let prog = store.loadProgress()
            let stats = store.getTodayStats()
            let due = store.getDueCards(limit: 999).count
            return (vocab, prog, stats, due)
        }
        guard !vocabulary.isEmpty else { return nil }

        var lines: [String] = ["[\(displayName)]"]

        // Overall stats
        lines.append("Total vocabulary: \(vocabulary.count) words")
        lines.append("Current streak: \(progress.currentStreak) day\(progress.currentStreak == 1 ? "" : "s") (longest: \(progress.longestStreak))")
        lines.append("Lifetime: \(progress.totalCardsReviewed) cards reviewed, \(progress.totalCorrect) correct")

        // Today's session
        if todayStats.cardsReviewed > 0 {
            let accuracy = todayStats.cardsReviewed > 0
                ? Int(Double(todayStats.correctCount) / Double(todayStats.cardsReviewed) * 100)
                : 0
            lines.append("Today: \(todayStats.cardsReviewed) cards reviewed (\(accuracy)% accuracy), \(todayStats.newCardsStudied) new")
            if todayStats.totalTime > 0 {
                let minutes = Int(todayStats.totalTime / 60)
                lines.append("Study time today: \(minutes) min")
            }
        } else {
            lines.append("Today: No cards reviewed yet")
        }

        // Due cards
        lines.append("Cards due now: \(dueCardCount)")

        // Category breakdown (top 5)
        let categories = Dictionary(grouping: vocabulary, by: { $0.category.rawValue })
        if categories.count > 1 {
            let sorted = categories.sorted { $0.value.count > $1.value.count }
            let top = sorted.prefix(5).map { "\($0.key): \($0.value.count)" }
            lines.append("Top categories: \(top.joined(separator: ", "))")
        }

        lines.append("[End \(displayName)]")
        return lines.joined(separator: "\n")
    }
}
