import Foundation

// MARK: - Vocabulary Category

/// Categories for vocabulary items, matching the Fluent PWA's classification.
enum VocabCategory: String, Codable, CaseIterable, Identifiable {
    case strategy = "Strategy"
    case execution = "Execution"
    case communication = "Communication"
    case assessment = "Assessment"
    case people = "People"
    case meeting = "Meeting"
    case idioms = "Idioms"
    case conflictResolution = "Conflict Resolution"
    case humor = "Humor"
    case career = "Career"
    case networking = "Networking"
    case phrasalVerbs = "Phrasal Verbs"
    case dailyLife = "Daily Life"
    case slangCasual = "Slang & Casual"
    case emotionsReactions = "Emotions & Reactions"
    case foodDining = "Food & Dining"
    case academicWriting = "Academic Writing"
    case techJargon = "Tech Jargon"
    case socialRelationships = "Social & Relationships"
    case proverbsWisdom = "Proverbs & Wisdom"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .strategy: return "target"
        case .execution: return "hammer.fill"
        case .communication: return "bubble.left.and.bubble.right.fill"
        case .assessment: return "chart.bar.fill"
        case .people: return "person.2.fill"
        case .meeting: return "video.fill"
        case .idioms: return "lightbulb.fill"
        case .conflictResolution: return "hand.raised.fill"
        case .humor: return "face.smiling.fill"
        case .career: return "briefcase.fill"
        case .networking: return "network"
        case .phrasalVerbs: return "text.word.spacing"
        case .dailyLife: return "house.fill"
        case .slangCasual: return "quote.bubble.fill"
        case .emotionsReactions: return "heart.fill"
        case .foodDining: return "fork.knife"
        case .academicWriting: return "doc.text.fill"
        case .techJargon: return "desktopcomputer"
        case .socialRelationships: return "person.3.fill"
        case .proverbsWisdom: return "book.fill"
        }
    }
}

// MARK: - Vocabulary Item

/// A single vocabulary term with definition, examples, and metadata.
struct VocabularyItem: Codable, Identifiable, Hashable {
    let id: String
    let term: String
    let definition: String
    var chineseDefinition: String?
    let category: VocabCategory
    let examples: [String]
    var usageNotes: String?
    var relatedTerms: [String]?
    let createdAt: Date
    var updatedAt: Date

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: VocabularyItem, rhs: VocabularyItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - FSRS Card State

/// Possible states for a card in the FSRS algorithm.
enum FSRSState: Int, Codable {
    case new = 0
    case learning = 1
    case review = 2
    case relearning = 3
}

// MARK: - FSRS Rating

/// User rating for a flashcard review.
enum FSRSRating: Int, Codable, CaseIterable {
    case again = 1
    case hard = 2
    case good = 3
    case easy = 4

    var label: String {
        switch self {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }
}

// MARK: - FSRS Card Data

/// FSRS algorithm state for a flashcard.
struct FSRSCardData: Codable {
    var due: Date
    var stability: Double
    var difficulty: Double
    var elapsedDays: Int
    var scheduledDays: Int
    var reps: Int
    var lapses: Int
    var state: FSRSState
    var lastReview: Date?
}

// MARK: - Flash Card Type

/// Types of flashcard challenges.
enum FlashCardType: String, Codable {
    case termToDef = "term-to-def"
    case defToTerm = "def-to-term"
    case fillBlank = "fill-blank"
}

// MARK: - Flash Card

/// A flashcard generated from a vocabulary item.
struct FlashCard: Codable, Identifiable {
    let id: String
    let vocabularyId: String
    let cardType: FlashCardType
    let front: String
    let back: String
    var fsrs: FSRSCardData
    let createdAt: Date
    var updatedAt: Date
}

// MARK: - Review Record

/// Record of a single flashcard review.
struct ReviewRecord: Codable, Identifiable {
    let id: String
    let cardId: String
    let rating: FSRSRating
    let reviewedAt: Date
    let elapsed: TimeInterval
}

// MARK: - Daily Stats

/// Daily review statistics.
struct DailyStats: Codable, Identifiable {
    let id: String // YYYY-MM-DD
    var cardsReviewed: Int
    var correctCount: Int
    var totalTime: TimeInterval
    var newCardsStudied: Int
}

// MARK: - User Progress

/// Overall user progress tracking.
struct FluentUserProgress: Codable {
    var currentStreak: Int
    var longestStreak: Int
    var lastStudyDate: Date?
    var totalCardsReviewed: Int
    var totalCorrect: Int
}

// MARK: - Fluent Settings

/// User-configurable settings for the Fluent module.
struct FluentSettings: Codable {
    var openaiApiKey: String?
    var ttsVoice: String
    var ttsSpeed: Double
    var showChinese: Bool
    var dailyGoal: Int
    var dailyNewCards: Int

    static let `default` = FluentSettings(
        openaiApiKey: nil,
        ttsVoice: "nova",
        ttsSpeed: 1.0,
        showChinese: true,
        dailyGoal: 20,
        dailyNewCards: 10
    )
}

// MARK: - TTS Voice

/// Available TTS voices for OpenAI API.
struct TTSVoiceOption: Identifiable {
    let id: String
    let name: String
    let description: String

    static let all: [TTSVoiceOption] = [
        TTSVoiceOption(id: "nova", name: "Nova", description: "Warm, friendly female"),
        TTSVoiceOption(id: "alloy", name: "Alloy", description: "Neutral, balanced"),
        TTSVoiceOption(id: "echo", name: "Echo", description: "Warm male"),
        TTSVoiceOption(id: "fable", name: "Fable", description: "British accent"),
        TTSVoiceOption(id: "onyx", name: "Onyx", description: "Deep male"),
        TTSVoiceOption(id: "shimmer", name: "Shimmer", description: "Clear female"),
    ]
}
