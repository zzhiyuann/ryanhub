import Foundation

// MARK: - Weight Entry

/// A single weight measurement record.
struct WeightEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let weight: Double // kg
    let note: String?

    init(id: UUID = UUID(), date: Date = Date(), weight: Double, note: String? = nil) {
        self.id = id
        self.date = date
        self.weight = weight
        self.note = note
    }

    /// Formatted weight string with one decimal place.
    var formattedWeight: String {
        String(format: "%.1f kg", weight)
    }

    /// Formatted date string.
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    /// Short date label for charts.
    var shortDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Food Entry

/// A single food/meal log entry with optional AI-analyzed nutritional data.
struct FoodEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let mealType: MealType
    let description: String
    let calories: Int?
    let protein: Int?
    let carbs: Int?
    let fat: Int?
    let items: [FoodItem]?
    let aiSummary: String?
    let isAIAnalyzed: Bool

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        mealType: MealType,
        description: String,
        calories: Int? = nil,
        protein: Int? = nil,
        carbs: Int? = nil,
        fat: Int? = nil,
        items: [FoodItem]? = nil,
        aiSummary: String? = nil,
        isAIAnalyzed: Bool = false
    ) {
        self.id = id
        self.date = date
        self.mealType = mealType
        self.description = description
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.items = items
        self.aiSummary = aiSummary
        self.isAIAnalyzed = isAIAnalyzed
    }

    /// Formatted time string.
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Food Item (sub-item within a meal)

/// Individual food item within a meal, typically from AI analysis.
struct FoodItem: Codable, Identifiable {
    let id: UUID
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let portion: String?

    init(id: UUID = UUID(), name: String, calories: Int, protein: Int = 0, carbs: Int = 0, fat: Int = 0, portion: String? = nil) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.portion = portion
    }
}

// MARK: - Meal Type

/// Classification of meals throughout the day.
enum MealType: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "cup.and.saucer.fill"
        }
    }
}

// MARK: - Exercise Item (sub-item within an activity)

/// Individual exercise within a workout, typically from AI analysis.
/// Supports both strength (sets/reps/weight) and cardio (duration).
struct ExerciseItem: Codable, Identifiable {
    var id: String { name }
    let name: String        // "Lat Pulldown"
    let sets: Int?          // 4
    let reps: Int?          // 12
    let weight: String?     // "70 lb"
    let duration: Int?      // minutes (for cardio)
    let caloriesBurned: Int?
}

// MARK: - Activity Entry

/// A single physical activity record.
struct ActivityEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: String
    let duration: Int // minutes
    let note: String?
    let rawDescription: String?
    let caloriesBurned: Int?
    let isAIAnalyzed: Bool
    let exercises: [ExerciseItem]
    let aiSummary: String?

    enum CodingKeys: String, CodingKey {
        case id, date, type, duration, note, rawDescription, caloriesBurned, isAIAnalyzed, exercises, aiSummary
    }

    init(id: UUID = UUID(), date: Date = Date(), type: String, duration: Int, note: String? = nil, rawDescription: String? = nil, caloriesBurned: Int? = nil, isAIAnalyzed: Bool = false, exercises: [ExerciseItem] = [], aiSummary: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.note = note
        self.rawDescription = rawDescription
        self.caloriesBurned = caloriesBurned
        self.isAIAnalyzed = isAIAnalyzed
        self.exercises = exercises
        self.aiSummary = aiSummary
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        type = try container.decode(String.self, forKey: .type)
        duration = try container.decode(Int.self, forKey: .duration)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        rawDescription = try container.decodeIfPresent(String.self, forKey: .rawDescription)
        caloriesBurned = try container.decodeIfPresent(Int.self, forKey: .caloriesBurned)
        isAIAnalyzed = try container.decodeIfPresent(Bool.self, forKey: .isAIAnalyzed) ?? false
        exercises = try container.decodeIfPresent([ExerciseItem].self, forKey: .exercises) ?? []
        aiSummary = try container.decodeIfPresent(String.self, forKey: .aiSummary)
    }

    /// Formatted duration string.
    var formattedDuration: String {
        if duration >= 60 {
            let hours = duration / 60
            let minutes = duration % 60
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }
        return "\(duration)m"
    }

    /// Formatted time string.
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Health Tab Selection

/// Tabs within the Health view.
enum HealthTab: String, CaseIterable, Identifiable {
    case weight
    case food
    case activity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .weight: return "Weight"
        case .food: return "Food"
        case .activity: return "Activity"
        }
    }

    var icon: String {
        switch self {
        case .weight: return "scalemass.fill"
        case .food: return "fork.knife"
        case .activity: return "figure.run"
        }
    }
}

// MARK: - Activity Parser

/// Parses natural language activity descriptions into structured type + duration.
/// Examples: "Walked 20 minutes to campus", "Gym session for 1 hour", "30 min yoga"
enum ActivityParser {
    /// Result of parsing a natural language activity description.
    struct ParseResult {
        let type: String
        let duration: Int? // minutes
        let note: String?
    }

    /// Known activity types with their keyword variants.
    private static let activityKeywords: [(type: String, keywords: [String], icon: String)] = [
        ("Walking", ["walk", "walked", "walking", "stroll", "strolled", "strolling", "hike", "hiked", "hiking"], "figure.walk"),
        ("Running", ["run", "ran", "running", "jog", "jogged", "jogging", "sprint", "sprinted", "sprinting"], "figure.run"),
        ("Gym", ["gym", "lift", "lifted", "lifting", "weights", "weight training", "strength", "workout", "work out", "worked out"], "dumbbell.fill"),
        ("Yoga", ["yoga", "stretch", "stretching", "stretched", "pilates"], "figure.yoga"),
        ("Swimming", ["swim", "swam", "swimming", "pool"], "figure.pool.swim"),
        ("Cycling", ["bike", "biked", "biking", "cycle", "cycled", "cycling", "bicycle"], "bicycle"),
        ("Dancing", ["dance", "danced", "dancing", "zumba"], "figure.dance"),
        ("Basketball", ["basketball", "hoops"], "basketball.fill"),
        ("Soccer", ["soccer", "football", "futsal"], "soccerball"),
        ("Tennis", ["tennis", "badminton", "racquet", "racket", "squash", "pickleball"], "tennis.racket"),
        ("Climbing", ["climb", "climbed", "climbing", "boulder", "bouldering"], "figure.climbing"),
        ("Rowing", ["row", "rowed", "rowing", "kayak", "kayaked", "kayaking", "canoe"], "figure.rowing"),
        ("Martial Arts", ["boxing", "boxed", "kickboxing", "martial arts", "karate", "taekwondo", "judo", "mma"], "figure.martial.arts"),
        ("Cardio", ["cardio", "elliptical", "treadmill", "stair", "stairs", "jump rope", "jumping"], "heart.fill"),
        ("Exercise", ["exercise", "exercised", "exercising", "training", "trained", "practice", "practiced"], "figure.mixed.cardio"),
    ]

    /// Parse a natural language description into structured activity data.
    static func parse(_ text: String) -> ParseResult {
        let lowered = text.lowercased().trimmingCharacters(in: .whitespaces)

        let activityType = detectActivityType(from: lowered)
        let duration = detectDuration(from: lowered)

        return ParseResult(
            type: activityType ?? "Activity",
            duration: duration,
            note: text.trimmingCharacters(in: .whitespaces)
        )
    }

    /// Detect activity type from text using keyword matching.
    private static func detectActivityType(from text: String) -> String? {
        for entry in activityKeywords {
            for keyword in entry.keywords {
                // Match whole words to avoid false positives (e.g., "swam" inside "swamp")
                let pattern = "\\b\(NSRegularExpression.escapedPattern(for: keyword))\\b"
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(text.startIndex..., in: text)
                    if regex.firstMatch(in: text, range: range) != nil {
                        return entry.type
                    }
                }
            }
        }
        return nil
    }

    /// Detect duration in minutes from text.
    /// Supports patterns like: "30 min", "1 hour", "1.5 hrs", "90 minutes", "1h 30m", "for 45 min"
    private static func detectDuration(from text: String) -> Int? {
        // Pattern: combined hours and minutes like "1h 30m", "1h30m", "2 hr 15 min"
        let combinedPattern = #"(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\s*(?:and\s+)?(\d+)\s*(?:m|min|mins|minutes|minute)"#
        if let regex = try? NSRegularExpression(pattern: combinedPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let hoursRange = Range(match.range(at: 1), in: text),
               let minsRange = Range(match.range(at: 2), in: text),
               let hours = Double(text[hoursRange]),
               let mins = Int(text[minsRange]) {
                return Int(hours * 60) + mins
            }
        }

        // Pattern: hours only like "1 hour", "2.5 hrs", "1.5 hours"
        let hoursPattern = #"(\d+(?:\.\d+)?)\s*(?:h|hr|hrs|hour|hours)\b"#
        if let regex = try? NSRegularExpression(pattern: hoursPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text),
               let hours = Double(text[range]) {
                return Int(hours * 60)
            }
        }

        // Pattern: minutes like "30 min", "45 minutes", "20m"
        let minutesPattern = #"(\d+)\s*(?:m|min|mins|minutes|minute)\b"#
        if let regex = try? NSRegularExpression(pattern: minutesPattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            if let range = Range(match.range(at: 1), in: text),
               let minutes = Int(text[range]) {
                return minutes
            }
        }

        // Pattern: standalone number at the beginning or after "for" (assume minutes)
        // e.g., "30 min run" or "ran for 30"
        let standalonePattern = #"(?:^|for\s+)(\d+)\s*$|^(\d+)\s+(?:min|minute)"#
        if let regex = try? NSRegularExpression(pattern: standalonePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) {
            for i in 1...2 {
                if match.range(at: i).location != NSNotFound,
                   let range = Range(match.range(at: i), in: text),
                   let minutes = Int(text[range]) {
                    return minutes
                }
            }
        }

        return nil
    }

    /// Get the SF Symbol icon for a given activity type.
    static func icon(for type: String) -> String {
        for entry in activityKeywords where entry.type == type {
            return entry.icon
        }
        return "figure.run"
    }
}
