import Foundation

// MARK: - RecipeBox Models

enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    case drink
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .snack: return "Snack"
        case .dessert: return "Dessert"
        case .drink: return "Drink"
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .snack: return "carrot"
        case .dessert: return "birthday.cake"
        case .drink: return "cup.and.saucer"
        }
    }
}

enum CuisineType: String, Codable, CaseIterable, Identifiable {
    case italian
    case mexican
    case chinese
    case japanese
    case indian
    case thai
    case american
    case mediterranean
    case korean
    case french
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .italian: return "Italian"
        case .mexican: return "Mexican"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .indian: return "Indian"
        case .thai: return "Thai"
        case .american: return "American"
        case .mediterranean: return "Mediterranean"
        case .korean: return "Korean"
        case .french: return "French"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .italian: return "fork.knife"
        case .mexican: return "fork.knife"
        case .chinese: return "fork.knife"
        case .japanese: return "fork.knife"
        case .indian: return "fork.knife"
        case .thai: return "fork.knife"
        case .american: return "fork.knife"
        case .mediterranean: return "fork.knife"
        case .korean: return "fork.knife"
        case .french: return "fork.knife"
        case .other: return "ellipsis.circle"
        }
    }
}

enum DifficultyLevel: String, Codable, CaseIterable, Identifiable {
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
        case .easy: return "leaf"
        case .medium: return "flame"
        case .hard: return "flame.fill"
        }
    }
}

struct RecipeBoxEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var title: String
    var category: MealCategory
    var cuisine: CuisineType
    var difficulty: DifficultyLevel
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var servings: Int
    var ingredients: [String]
    var steps: [String]
    var rating: Int
    var isFavorite: Bool
    var cookCount: Int
    var notes: String
    var sourceURL: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(title)")
        parts.append("\(category)")
        parts.append("\(cuisine)")
        parts.append("\(difficulty)")
        parts.append("\(prepTimeMinutes)")
        parts.append("\(cookTimeMinutes)")
        parts.append("\(servings)")
        parts.append("\(ingredients)")
        parts.append("\(steps)")
        parts.append("\(rating)")
        parts.append("\(isFavorite)")
        parts.append("\(cookCount)")
        parts.append("\(notes)")
        parts.append("\(sourceURL)")
        return parts.joined(separator: " | ")
    }
}
