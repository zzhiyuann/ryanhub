import Foundation

// MARK: - FSRS Engine

/// A Swift implementation of the Free Spaced Repetition Scheduler (FSRS) algorithm.
/// Based on the open-source FSRS-4.5 spec: https://github.com/open-spaced-repetition/fsrs4anki
///
/// This is a simplified but faithful port of the core scheduling logic.
enum FSRSEngine {

    // MARK: - Parameters (FSRS-4.5 defaults)

    /// Default parameters for FSRS-4.5, tuned for general use.
    private static let w: [Double] = [
        0.4, 0.6, 2.4, 5.8,   // w[0..3]: initial stability for Again/Hard/Good/Easy
        4.93, 0.94, 0.86, 0.01, // w[4..7]: difficulty parameters
        1.49, 0.14, 0.94,       // w[8..10]: stability growth
        2.18, 0.05, 0.34,       // w[11..13]: recall parameters
        1.26, 0.29, 2.61        // w[14..16]: additional modifiers
    ]

    /// Desired retention rate (90%).
    private static let requestRetention: Double = 0.9

    /// Maximum review interval in days.
    private static let maximumInterval: Int = 36500

    // MARK: - Public API

    /// Create initial FSRS card data for a new card.
    static func createNewCard() -> FSRSCardData {
        FSRSCardData(
            due: Date(),
            stability: 0,
            difficulty: 0,
            elapsedDays: 0,
            scheduledDays: 0,
            reps: 0,
            lapses: 0,
            state: .new,
            lastReview: nil
        )
    }

    /// Schedule the next review for a card given a rating.
    /// Returns updated FSRSCardData.
    static func review(card: FSRSCardData, rating: FSRSRating, now: Date = Date()) -> FSRSCardData {
        var result = card

        // Calculate elapsed days since last review
        let elapsedDays: Int
        if let lastReview = card.lastReview {
            elapsedDays = max(0, Calendar.current.dateComponents([.day], from: lastReview, to: now).day ?? 0)
        } else {
            elapsedDays = 0
        }
        result.elapsedDays = elapsedDays
        result.lastReview = now
        result.reps += 1

        switch card.state {
        case .new:
            result = scheduleNew(card: result, rating: rating, now: now)

        case .learning, .relearning:
            result = scheduleLearning(card: result, rating: rating, now: now)

        case .review:
            result = scheduleReview(card: result, rating: rating, elapsedDays: elapsedDays, now: now)
        }

        return result
    }

    /// Get the next review interval for each possible rating (for preview in UI).
    static func previewIntervals(for card: FSRSCardData) -> [FSRSRating: Int] {
        var result: [FSRSRating: Int] = [:]
        let now = Date()
        for rating in FSRSRating.allCases {
            let reviewed = review(card: card, rating: rating, now: now)
            result[rating] = reviewed.scheduledDays
        }
        return result
    }

    // MARK: - Private Scheduling

    private static func scheduleNew(card: FSRSCardData, rating: FSRSRating, now: Date) -> FSRSCardData {
        var result = card
        let ratingIndex = rating.rawValue - 1 // 0-based
        result.difficulty = initDifficulty(rating: rating)
        result.stability = w[ratingIndex]

        switch rating {
        case .again:
            result.state = .learning
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(60) // 1 minute
            result.lapses += 1

        case .hard:
            result.state = .learning
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(5 * 60) // 5 minutes

        case .good:
            result.state = .learning
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(10 * 60) // 10 minutes

        case .easy:
            let interval = nextInterval(stability: result.stability)
            result.state = .review
            result.scheduledDays = interval
            result.due = Calendar.current.date(byAdding: .day, value: interval, to: now) ?? now
        }

        return result
    }

    private static func scheduleLearning(card: FSRSCardData, rating: FSRSRating, now: Date) -> FSRSCardData {
        var result = card

        switch rating {
        case .again:
            result.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            result.stability = max(w[0], card.stability * 0.7)
            result.state = card.state == .learning ? .learning : .relearning
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(5 * 60) // 5 minutes
            result.lapses += 1

        case .hard:
            result.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            result.stability = max(card.stability, w[1])
            result.state = card.state
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(10 * 60) // 10 minutes

        case .good:
            result.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            result.stability = max(card.stability, w[2])
            let interval = nextInterval(stability: result.stability)
            result.state = .review
            result.scheduledDays = max(1, interval)
            result.due = Calendar.current.date(byAdding: .day, value: result.scheduledDays, to: now) ?? now

        case .easy:
            result.difficulty = nextDifficulty(d: card.difficulty, rating: rating)
            result.stability = max(card.stability, w[3])
            let interval = nextInterval(stability: result.stability)
            result.state = .review
            result.scheduledDays = max(1, interval)
            result.due = Calendar.current.date(byAdding: .day, value: result.scheduledDays, to: now) ?? now
        }

        return result
    }

    private static func scheduleReview(card: FSRSCardData, rating: FSRSRating, elapsedDays: Int, now: Date) -> FSRSCardData {
        var result = card
        let d = nextDifficulty(d: card.difficulty, rating: rating)
        result.difficulty = d

        switch rating {
        case .again:
            let s = nextForgetStability(
                d: d,
                s: card.stability,
                r: retrievability(elapsedDays: elapsedDays, stability: card.stability)
            )
            result.stability = s
            result.state = .relearning
            result.scheduledDays = 0
            result.due = now.addingTimeInterval(5 * 60)
            result.lapses += 1

        case .hard:
            let s = nextRecallStability(
                d: d, s: card.stability,
                r: retrievability(elapsedDays: elapsedDays, stability: card.stability),
                rating: rating
            )
            result.stability = s
            let interval = nextInterval(stability: s)
            result.scheduledDays = max(1, interval)
            result.due = Calendar.current.date(byAdding: .day, value: result.scheduledDays, to: now) ?? now

        case .good:
            let s = nextRecallStability(
                d: d, s: card.stability,
                r: retrievability(elapsedDays: elapsedDays, stability: card.stability),
                rating: rating
            )
            result.stability = s
            let interval = nextInterval(stability: s)
            result.scheduledDays = max(1, interval)
            result.due = Calendar.current.date(byAdding: .day, value: result.scheduledDays, to: now) ?? now

        case .easy:
            let s = nextRecallStability(
                d: d, s: card.stability,
                r: retrievability(elapsedDays: elapsedDays, stability: card.stability),
                rating: rating
            )
            result.stability = s
            let interval = nextInterval(stability: s)
            result.scheduledDays = max(1, interval)
            result.due = Calendar.current.date(byAdding: .day, value: result.scheduledDays, to: now) ?? now
        }

        return result
    }

    // MARK: - Core FSRS Math

    /// Initialize difficulty for a new card.
    private static func initDifficulty(rating: FSRSRating) -> Double {
        let d = w[4] - exp(Double(rating.rawValue - 1) * w[5]) + 1
        return clampDifficulty(d)
    }

    /// Calculate next difficulty after a review.
    private static func nextDifficulty(d: Double, rating: FSRSRating) -> Double {
        let delta = -(w[6] * (Double(rating.rawValue) - 3))
        let nextD = d + delta * meanReversion(init: w[4], current: d)
        return clampDifficulty(nextD)
    }

    /// Mean reversion factor for difficulty updates.
    private static func meanReversion(init initVal: Double, current: Double) -> Double {
        return w[7] * initVal + (1 - w[7]) * current
    }

    /// Clamp difficulty to [1, 10] range.
    private static func clampDifficulty(_ d: Double) -> Double {
        return min(10, max(1, d))
    }

    /// Calculate retrievability (probability of recall) based on elapsed time and stability.
    private static func retrievability(elapsedDays: Int, stability: Double) -> Double {
        guard stability > 0 else { return 0 }
        return pow(1 + Double(elapsedDays) / (9 * stability), -1)
    }

    /// Calculate the next interval in days based on desired retention.
    private static func nextInterval(stability: Double) -> Int {
        guard stability > 0 else { return 1 }
        let interval = 9 * stability * (1 / requestRetention - 1)
        return min(maximumInterval, max(1, Int(round(interval))))
    }

    /// Calculate next stability after successful recall.
    private static func nextRecallStability(d: Double, s: Double, r: Double, rating: FSRSRating) -> Double {
        let hardPenalty = rating == .hard ? w[15] : 1.0
        let easyBonus = rating == .easy ? w[16] : 1.0
        let newS = s * (1 + exp(w[8]) *
            (11 - d) *
            pow(s, -w[9]) *
            (exp((1 - r) * w[10]) - 1) *
            hardPenalty * easyBonus)
        return max(0.01, newS)
    }

    /// Calculate next stability after a lapse (forgot the card).
    private static func nextForgetStability(d: Double, s: Double, r: Double) -> Double {
        let newS = w[11] *
            pow(d, -w[12]) *
            (pow(s + 1, w[13]) - 1) *
            exp((1 - r) * w[14])
        return max(0.01, min(s, newS))
    }
}

// MARK: - Interval Formatting

extension FSRSEngine {
    /// Format an interval in days as a human-readable string.
    static func formatInterval(_ days: Int) -> String {
        if days == 0 {
            return "< 1d"
        } else if days == 1 {
            return "1d"
        } else if days < 30 {
            return "\(days)d"
        } else if days < 365 {
            let months = days / 30
            return "\(months)mo"
        } else {
            let years = Double(days) / 365.0
            return String(format: "%.1fy", years)
        }
    }
}
