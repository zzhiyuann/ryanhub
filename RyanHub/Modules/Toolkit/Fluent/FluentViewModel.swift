import Foundation
import AVFoundation

// MARK: - Fluent Tab

/// Internal navigation tabs for the Fluent module.
enum FluentTab: String, CaseIterable {
    case dashboard
    case vocabulary
    case review
}

// MARK: - Fluent View Model

/// Manages all state for the native Fluent module.
/// Handles vocabulary browsing, flashcard review sessions with FSRS scheduling,
/// TTS pronunciation, and user settings.
@MainActor
@Observable
final class FluentViewModel {

    // MARK: - Navigation

    var selectedTab: FluentTab = .dashboard
    var showSettings = false
    var showVocabularyDetail = false
    var selectedVocabItem: VocabularyItem?

    // MARK: - Dashboard

    var wordOfTheDay: VocabularyItem?
    var dueCardCount: Int = 0
    var todayStats: DailyStats = DailyStats(id: "", cardsReviewed: 0, correctCount: 0, totalTime: 0, newCardsStudied: 0)
    var progress: FluentUserProgress = FluentUserProgress(currentStreak: 0, longestStreak: 0, lastStudyDate: nil, totalCardsReviewed: 0, totalCorrect: 0)

    // MARK: - Vocabulary

    var allVocabulary: [VocabularyItem] = []
    var searchText: String = ""
    var selectedCategory: VocabCategory?

    var filteredVocabulary: [VocabularyItem] {
        var items = allVocabulary
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            items = items.filter {
                $0.term.lowercased().contains(query)
                || $0.definition.lowercased().contains(query)
                || ($0.chineseDefinition?.contains(query) ?? false)
            }
        }
        return items
    }

    // MARK: - Review

    var reviewCards: [FlashCard] = []
    var currentCardIndex: Int = 0
    var isFlipped: Bool = false
    var isReviewComplete: Bool = false
    var isAnimating: Bool = false
    var sessionReviewed: Int = 0
    var sessionCorrect: Int = 0
    var sessionStartTime: Date?
    var previewIntervals: [FSRSRating: Int] = [:]

    var currentCard: FlashCard? {
        guard currentCardIndex < reviewCards.count else { return nil }
        return reviewCards[currentCardIndex]
    }

    var reviewProgress: Double {
        guard !reviewCards.isEmpty else { return 0 }
        return Double(currentCardIndex) / Double(reviewCards.count)
    }

    // MARK: - Settings

    var settings: FluentSettings = .default

    // MARK: - TTS

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Store

    private let store = FluentStore.shared

    // MARK: - Initialization

    func loadData() {
        let seeded = store.seedIfNeeded()
        allVocabulary = store.loadVocabulary()
        settings = store.loadSettings()
        progress = store.loadProgress()
        todayStats = store.getTodayStats()
        dueCardCount = store.getDueCards().count
        wordOfTheDay = pickWordOfTheDay()

        if seeded {
            // Re-count after seeding
            dueCardCount = store.getDueCards().count
        }
    }

    /// Refresh dashboard-visible stats (call when switching back to dashboard tab).
    func refreshDashboard() {
        progress = store.loadProgress()
        todayStats = store.getTodayStats()
        dueCardCount = store.getDueCards().count
    }

    // MARK: - Word of the Day

    /// Pick a deterministic word of the day based on the current date.
    private func pickWordOfTheDay() -> VocabularyItem? {
        guard !allVocabulary.isEmpty else { return nil }
        let calendar = Calendar.current
        let day = calendar.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let index = day % allVocabulary.count
        return allVocabulary[index]
    }

    // MARK: - Review Session

    func startReviewSession() {
        let dueCards = store.getDueCards(limit: 50)
        reviewCards = dueCards
        currentCardIndex = 0
        isFlipped = false
        isReviewComplete = false
        sessionReviewed = 0
        sessionCorrect = 0
        sessionStartTime = Date()
        previewIntervals = [:]

        if let card = currentCard {
            previewIntervals = FSRSEngine.previewIntervals(for: card.fsrs)
        }
    }

    func restartReview() {
        isReviewComplete = false
        startReviewSession()
    }

    func flipCard() {
        guard !isAnimating else { return }
        isFlipped = true
    }

    func rateCard(_ rating: FSRSRating) {
        guard !isAnimating, let card = currentCard else { return }
        isAnimating = true

        // Apply FSRS scheduling
        let updated = FSRSEngine.review(card: card.fsrs, rating: rating)
        var updatedCard = card
        updatedCard.fsrs = updated
        updatedCard.updatedAt = Date()

        // Save updated card
        store.updateFlashcard(updatedCard)

        // Track session stats
        sessionReviewed += 1
        if rating != .again {
            sessionCorrect += 1
        }

        // Save review record
        let record = ReviewRecord(
            id: UUID().uuidString,
            cardId: card.id,
            rating: rating,
            reviewedAt: Date(),
            elapsed: 0
        )
        store.saveReview(record)

        // Move to next card or finish
        let nextIndex = currentCardIndex + 1
        if nextIndex >= reviewCards.count {
            // Session complete
            finishReviewSession()
        } else {
            // Advance to next card
            currentCardIndex = nextIndex
            isFlipped = false
            if let nextCard = currentCard {
                previewIntervals = FSRSEngine.previewIntervals(for: nextCard.fsrs)
            }
        }

        // Update due count immediately so dashboard stays current
        dueCardCount = store.getDueCards().count

        // Brief animation delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.isAnimating = false
        }
    }

    private func finishReviewSession() {
        isReviewComplete = true

        let timeSpent = sessionStartTime.map { Date().timeIntervalSince($0) } ?? 0

        // Update progress
        store.updateProgressAfterReview(reviewed: sessionReviewed, correct: sessionCorrect)
        store.updateTodayStats(
            reviewed: sessionReviewed,
            correct: sessionCorrect,
            timeSpent: timeSpent,
            newCards: 0
        )

        // Refresh dashboard data
        progress = store.loadProgress()
        todayStats = store.getTodayStats()
        dueCardCount = store.getDueCards().count
    }

    // MARK: - TTS

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = Float(settings.ttsSpeed) * AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0

        synthesizer.speak(utterance)
    }

    // MARK: - Settings

    func saveSettings() {
        store.saveSettings(settings)
    }

    // MARK: - Vocabulary Detail

    func showDetail(for item: VocabularyItem) {
        selectedVocabItem = item
        showVocabularyDetail = true
    }
}
