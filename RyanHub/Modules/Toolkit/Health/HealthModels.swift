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

// MARK: - Activity Entry

/// A single physical activity record.
struct ActivityEntry: Codable, Identifiable {
    let id: UUID
    let date: Date
    let type: String
    let duration: Int // minutes
    let note: String?

    init(id: UUID = UUID(), date: Date = Date(), type: String, duration: Int, note: String? = nil) {
        self.id = id
        self.date = date
        self.type = type
        self.duration = duration
        self.note = note
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
