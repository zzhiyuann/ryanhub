import Foundation

// MARK: - RecipeBox Models

enum MealCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case appetizer
    case dessert
    case snack
    case drink
    case side
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .breakfast: return "Breakfast"
        case .lunch: return "Lunch"
        case .dinner: return "Dinner"
        case .appetizer: return "Appetizer"
        case .dessert: return "Dessert"
        case .snack: return "Snack"
        case .drink: return "Drink"
        case .side: return "Side Dish"
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sun.horizon"
        case .lunch: return "sun.max"
        case .dinner: return "moon.stars"
        case .appetizer: return "fork.knife"
        case .dessert: return "birthday.cake"
        case .snack: return "carrot"
        case .drink: return "cup.and.saucer"
        case .side: return "leaf"
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
    case french
    case mediterranean
    case korean
    case american
    case middleEastern
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
        case .french: return "French"
        case .mediterranean: return "Mediterranean"
        case .korean: return "Korean"
        case .american: return "American"
        case .middleEastern: return "Middle Eastern"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .italian: return "globe.europe.africa"
        case .mexican: return "globe.americas"
        case .chinese: return "globe.asia.australia"
        case .japanese: return "globe.asia.australia"
        case .indian: return "globe.asia.australia"
        case .thai: return "globe.asia.australia"
        case .french: return "globe.europe.africa"
        case .mediterranean: return "globe.europe.africa"
        case .korean: return "globe.asia.australia"
        case .american: return "globe.americas"
        case .middleEastern: return "globe.europe.africa"
        case .other: return "globe"
        }
    }
}

enum DifficultyLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case easy
    case medium
    case hard
    case expert
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .easy: return "Easy"
        case .medium: return "Medium"
        case .hard: return "Hard"
        case .expert: return "Expert"
        }
    }
    var icon: String {
        switch self {
        case .beginner: return "1.circle"
        case .easy: return "2.circle"
        case .medium: return "3.circle"
        case .hard: return "4.circle"
        case .expert: return "star.circle"
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
    var name: String
    var category: MealCategory
    var cuisine: CuisineType
    var ingredients: String
    var servings: Int
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var difficulty: DifficultyLevel
    var rating: Int
    var notes: String
    var isFavorite: Bool
    var timesCooked: Int

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(name)")
        parts.append("\(category)")
        parts.append("\(cuisine)")
        parts.append("\(ingredients)")
        parts.append("\(servings)")
        parts.append("\(prepTimeMinutes)")
        parts.append("\(cookTimeMinutes)")
        parts.append("\(difficulty)")
        parts.append("\(rating)")
        parts.append("\(notes)")
        parts.append("\(isFavorite)")
        parts.append("\(timesCooked)")
        return parts.joined(separator: " | ")
    }
}
