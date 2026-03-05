import Foundation

// MARK: - Enums

enum MealCategory: String, CaseIterable, Codable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    case appetizer
    case drink

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        case .appetizer: return "Appetizer"
        case .drink: return "Drink"
        }
    }

    var icon: String {
        switch self {
        case .breakfast: return "sunrise"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "carrot"
        case .dessert: return "birthday.cake"
        case .appetizer: return "fork.knife"
        case .drink: return "cup.and.saucer"
        }
    }
}

enum CuisineType: String, CaseIterable, Codable, Identifiable {
    case italian
    case chinese
    case japanese
    case mexican
    case indian
    case american
    case mediterranean
    case thai
    case french
    case korean
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .italian: return "Italian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .mexican: return "Mexican"
        case .indian: return "Indian"
        case .american: return "American"
        case .mediterranean: return "Mediterranean"
        case .thai: return "Thai"
        case .french: return "French"
        case .korean: return "Korean"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .mediterranean: return "leaf"
        case .other: return "globe"
        default: return "flag"
        }
    }
}

enum DifficultyLevel: String, CaseIterable, Codable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        }
    }

    var icon: String {
        switch self {
        case .easy: return "gauge.with.dots.needle.0percent"
        case .medium: return "gauge.with.dots.needle.50percent"
        case .hard: return "gauge.with.dots.needle.100percent"
        }
    }

    var sortOrder: Int {
        switch self {
        case .easy: return 0
        case .medium: return 1
        case .hard: return 2
        }
    }
}

// MARK: - Entry

struct RecipeBoxEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()

    var name: String = ""
    var category: MealCategory = .dinner
    var cuisine: CuisineType = .other
    var servings: Int = 2
    var prepTimeMinutes: Int = 15
    var cookTimeMinutes: Int = 30
    var difficulty: DifficultyLevel = .medium
    var ingredients: String = ""
    var instructions: String = ""
    var rating: Double = 0.0
    var isFavorite: Bool = false
    var timesCooked: Int = 0
    var notes: String = ""

    // MARK: Computed — Date

    var formattedDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .medium
        out.timeStyle = .short
        return out.string(from: d)
    }

    var dateValue: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: date)
    }

    var shortDate: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        guard let d = f.date(from: date) else { return date }
        let out = DateFormatter()
        out.dateStyle = .short
        return out.string(from: d)
    }

    // MARK: Computed — Time

    var totalTimeMinutes: Int {
        prepTimeMinutes + cookTimeMinutes
    }

    var formattedTotalTime: String {
        let total = totalTimeMinutes
        if total < 60 {
            return "\(total) min"
        }
        let hours = total / 60
        let minutes = total % 60
        return minutes == 0 ? "\(hours)h" : "\(hours)h \(minutes)m"
    }

    var formattedPrepTime: String {
        prepTimeMinutes < 60 ? "\(prepTimeMinutes) min" : "\(prepTimeMinutes / 60)h \(prepTimeMinutes % 60 == 0 ? "" : "\(prepTimeMinutes % 60)m")".trimmingCharacters(in: .whitespaces)
    }

    var formattedCookTime: String {
        cookTimeMinutes < 60 ? "\(cookTimeMinutes) min" : "\(cookTimeMinutes / 60)h \(cookTimeMinutes % 60 == 0 ? "" : "\(cookTimeMinutes % 60)m")".trimmingCharacters(in: .whitespaces)
    }

    var isQuickRecipe: Bool {
        totalTimeMinutes <= 30
    }

    // MARK: Computed — Rating

    var formattedRating: String {
        rating > 0 ? String(format: "%.1f", rating) : "—"
    }

    var ratingStars: String {
        guard rating > 0 else { return "☆☆☆☆☆" }
        let filled = Int((rating / 2.0).rounded())
        let empty = 5 - filled
        return String(repeating: "★", count: max(0, filled)) + String(repeating: "☆", count: max(0, empty))
    }

    var hasBeenRated: Bool {
        rating > 0
    }

    // MARK: Computed — Ingredients

    var ingredientList: [String] {
        ingredients
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var ingredientCount: Int {
        ingredientList.count
    }

    // MARK: Computed — Summary

    var summaryLine: String {
        var parts: [String] = []
        parts.append(category.displayName)
        parts.append(cuisine.displayName)
        if totalTimeMinutes > 0 {
            parts.append(formattedTotalTime)
        }
        if hasBeenRated {
            parts.append("\(formattedRating)★")
        }
        return parts.joined(separator: " · ")
    }

    var timeCookedLabel: String {
        switch timesCooked {
        case 0: return "Never cooked"
        case 1: return "Cooked once"
        default: return "Cooked \(timesCooked)×"
        }
    }

    var servingsLabel: String {
        servings == 1 ? "1 serving" : "\(servings) servings"
    }
}