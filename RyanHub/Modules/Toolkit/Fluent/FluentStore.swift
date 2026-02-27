import Foundation

// MARK: - Fluent Store

/// Persistence layer for the Fluent module.
/// Stores vocabulary, flashcards, review records, and settings using JSON files
/// in the app's documents directory for efficient local-first storage.
@MainActor
final class FluentStore {

    static let shared = FluentStore()

    // MARK: - File Paths

    private let fileManager = FileManager.default

    private var storeDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("FluentData", isDirectory: true)
        try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var vocabularyURL: URL { storeDirectory.appendingPathComponent("vocabulary.json") }
    private var flashcardsURL: URL { storeDirectory.appendingPathComponent("flashcards.json") }
    private var reviewsURL: URL { storeDirectory.appendingPathComponent("reviews.json") }
    private var progressURL: URL { storeDirectory.appendingPathComponent("progress.json") }
    private var dailyStatsURL: URL { storeDirectory.appendingPathComponent("daily-stats.json") }
    private var settingsURL: URL { storeDirectory.appendingPathComponent("settings.json") }

    // MARK: - Encoder / Decoder

    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Generic Load / Save

    private func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T, to url: URL) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Vocabulary

    func loadVocabulary() -> [VocabularyItem] {
        load([VocabularyItem].self, from: vocabularyURL) ?? []
    }

    func saveVocabulary(_ items: [VocabularyItem]) {
        save(items, to: vocabularyURL)
    }

    /// Seed database if empty, or incrementally sync new vocabulary from seed data.
    /// Returns true if any new items were added.
    func seedIfNeeded() -> Bool {
        let existing = loadVocabulary()

        if existing.isEmpty {
            // Fresh install — seed everything
            let seed = FluentSeedData.allVocabulary
            saveVocabulary(seed)
            let cards = seed.flatMap { FluentStore.generateFlashcards(for: $0) }
            saveFlashcards(cards)
            return true
        }

        // Incremental sync — add any seed items not already in local store
        let existingIds = Set(existing.map { $0.id })
        let seed = FluentSeedData.allVocabulary
        let newItems = seed.filter { !existingIds.contains($0.id) }

        guard !newItems.isEmpty else { return false }

        // Append new vocabulary
        saveVocabulary(existing + newItems)

        // Generate and append flashcards for new items only
        var existingCards = loadFlashcards()
        let newCards = newItems.flatMap { FluentStore.generateFlashcards(for: $0) }
        existingCards.append(contentsOf: newCards)
        saveFlashcards(existingCards)

        return true
    }

    // MARK: - Flashcards

    func loadFlashcards() -> [FlashCard] {
        load([FlashCard].self, from: flashcardsURL) ?? []
    }

    func saveFlashcards(_ cards: [FlashCard]) {
        save(cards, to: flashcardsURL)
    }

    func updateFlashcard(_ card: FlashCard) {
        var cards = loadFlashcards()
        if let index = cards.firstIndex(where: { $0.id == card.id }) {
            cards[index] = card
        }
        saveFlashcards(cards)
    }

    /// Get due cards, one per word (random card type for variety).
    /// Returns up to `limit` unique vocabulary words, each represented by one flashcard.
    func getDueCards(limit: Int = 50) -> [FlashCard] {
        let now = Date()
        let cards = loadFlashcards()
        let dueCards = cards.filter { $0.fsrs.due <= now }

        // Group by vocabulary word
        var byWord: [String: [FlashCard]] = [:]
        for card in dueCards {
            byWord[card.vocabularyId, default: []].append(card)
        }

        // Pick one card per word (random type for variety across sessions)
        var result: [FlashCard] = byWord.compactMap { _, wordCards in
            wordCards.randomElement()
        }

        // Sort by earliest due date, then limit
        result.sort { $0.fsrs.due < $1.fsrs.due }
        return Array(result.prefix(limit))
    }

    /// Update FSRS state for ALL cards belonging to the same word.
    func updateWordCards(vocabularyId: String, fsrs: FSRSCardData) {
        var cards = loadFlashcards()
        let now = Date()
        for i in cards.indices where cards[i].vocabularyId == vocabularyId {
            cards[i].fsrs = fsrs
            cards[i].updatedAt = now
        }
        saveFlashcards(cards)
    }

    // MARK: - Flashcard Generation

    /// Generate flashcards for a vocabulary item.
    static func generateFlashcards(for vocab: VocabularyItem) -> [FlashCard] {
        let now = Date()
        var cards: [FlashCard] = []

        // Term -> Definition
        cards.append(FlashCard(
            id: "\(vocab.id)::term-to-def",
            vocabularyId: vocab.id,
            cardType: .termToDef,
            front: vocab.term,
            back: vocab.definition + (vocab.chineseDefinition.map { "\n\n\($0)" } ?? ""),
            fsrs: FSRSEngine.createNewCard(),
            createdAt: now,
            updatedAt: now
        ))

        // Definition -> Term
        cards.append(FlashCard(
            id: "\(vocab.id)::def-to-term",
            vocabularyId: vocab.id,
            cardType: .defToTerm,
            front: vocab.definition,
            back: vocab.term,
            fsrs: FSRSEngine.createNewCard(),
            createdAt: now,
            updatedAt: now
        ))

        // Fill in the blank (if first example contains the term)
        if let example = vocab.examples.first {
            let termLower = vocab.term.lowercased()
            let exLower = example.lowercased()
            if let range = exLower.range(of: termLower) {
                let nsRange = NSRange(range, in: exLower)
                let original = example as NSString
                let blank = original.replacingCharacters(in: nsRange, with: "________")
                cards.append(FlashCard(
                    id: "\(vocab.id)::fill-blank",
                    vocabularyId: vocab.id,
                    cardType: .fillBlank,
                    front: "Fill in the blank:\n\n\"\(blank)\"",
                    back: vocab.term,
                    fsrs: FSRSEngine.createNewCard(),
                    createdAt: now,
                    updatedAt: now
                ))
            }
        }

        return cards
    }

    // MARK: - Reviews

    func loadReviews() -> [ReviewRecord] {
        load([ReviewRecord].self, from: reviewsURL) ?? []
    }

    func saveReview(_ record: ReviewRecord) {
        var reviews = loadReviews()
        reviews.append(record)
        save(reviews, to: reviewsURL)
    }

    // MARK: - Progress

    func loadProgress() -> FluentUserProgress {
        load(FluentUserProgress.self, from: progressURL) ?? FluentUserProgress(
            currentStreak: 0,
            longestStreak: 0,
            lastStudyDate: nil,
            totalCardsReviewed: 0,
            totalCorrect: 0
        )
    }

    func saveProgress(_ progress: FluentUserProgress) {
        save(progress, to: progressURL)
    }

    /// Update progress after a review session.
    func updateProgressAfterReview(reviewed: Int, correct: Int) {
        var progress = loadProgress()
        progress.totalCardsReviewed += reviewed
        progress.totalCorrect += correct

        // Update streak
        let today = Calendar.current.startOfDay(for: Date())
        if let lastDate = progress.lastStudyDate {
            let lastDay = Calendar.current.startOfDay(for: lastDate)
            let dayDiff = Calendar.current.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayDiff == 1 {
                // Consecutive day
                progress.currentStreak += 1
            } else if dayDiff > 1 {
                // Streak broken
                progress.currentStreak = 1
            }
            // dayDiff == 0 means same day, don't increment streak
        } else {
            progress.currentStreak = 1
        }
        progress.longestStreak = max(progress.longestStreak, progress.currentStreak)
        progress.lastStudyDate = Date()
        saveProgress(progress)
    }

    // MARK: - Daily Stats

    func loadDailyStats() -> [DailyStats] {
        load([DailyStats].self, from: dailyStatsURL) ?? []
    }

    func getTodayStats() -> DailyStats {
        let todayId = Self.dateId(for: Date())
        let stats = loadDailyStats()
        return stats.first { $0.id == todayId } ?? DailyStats(
            id: todayId,
            cardsReviewed: 0,
            correctCount: 0,
            totalTime: 0,
            newCardsStudied: 0
        )
    }

    func updateTodayStats(reviewed: Int, correct: Int, timeSpent: TimeInterval, newCards: Int) {
        let todayId = Self.dateId(for: Date())
        var allStats = loadDailyStats()
        if let index = allStats.firstIndex(where: { $0.id == todayId }) {
            allStats[index].cardsReviewed += reviewed
            allStats[index].correctCount += correct
            allStats[index].totalTime += timeSpent
            allStats[index].newCardsStudied += newCards
        } else {
            allStats.append(DailyStats(
                id: todayId,
                cardsReviewed: reviewed,
                correctCount: correct,
                totalTime: timeSpent,
                newCardsStudied: newCards
            ))
        }
        save(allStats, to: dailyStatsURL)
    }

    private static func dateId(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Settings

    func loadSettings() -> FluentSettings {
        load(FluentSettings.self, from: settingsURL) ?? .default
    }

    func saveSettings(_ settings: FluentSettings) {
        save(settings, to: settingsURL)
    }
}
