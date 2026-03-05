import Foundation

// MARK: - RecipeBox Models

enum RecipeCategory: String, Codable, CaseIterable, Identifiable {
    case breakfast
    case lunch
    case dinner
    case snack
    case dessert
    case appetizer
    case side
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
        case .side: return "Side Dish"
        case .drink: return "Drink"
        }
    }
    var icon: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.fill"
        case .snack: return "leaf.fill"
        case .dessert: return "birthday.cake.fill"
        case .appetizer: return "fork.knife.circle.fill"
        case .side: return "leaf.circle.fill"
        case .drink: return "cup.and.saucer.fill"
        }
    }
}

enum CuisineType: String, Codable, CaseIterable, Identifiable {
    case italian
    case chinese
    case japanese
    case mexican
    case indian
    case thai
    case french
    case american
    case korean
    case mediterranean
    case other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .italian: return "Italian"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        case .mexican: return "Mexican"
        case .indian: return "Indian"
        case .thai: return "Thai"
        case .french: return "French"
        case .american: return "American"
        case .korean: return "Korean"
        case .mediterranean: return "Mediterranean"
        case .other: return "Other"
        }
    }
    var icon: String {
        switch self {
        case .italian: return "fork.knife"
        case .chinese: return "flame.fill"
        case .japanese: return "leaf.fill"
        case .mexican: return "sun.max.fill"
        case .indian: return "sparkles"
        case .thai: return "star.fill"
        case .french: return "wineglass.fill"
        case .american: return "star.circle.fill"
        case .korean: return "flame.circle.fill"
        case .mediterranean: return "globe.europe.africa.fill"
        case .other: return "ellipsis.circle.fill"
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
        case .easy: return "1.circle.fill"
        case .medium: return "2.circle.fill"
        case .hard: return "3.circle.fill"
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
    var category: RecipeCategory
    var cuisine: CuisineType
    var difficulty: DifficultyLevel
    var prepTimeMinutes: Int
    var cookTimeMinutes: Int
    var servings: Int
    var rating: Int
    var ingredients: String
    var instructions: String
    var isFavorite: Bool
    var timesCooked: Int
    var caloriesPerServing: Int
    var notes: String

    var summaryLine: String {
        var parts: [String] = [date]
        parts.append("\(name)")
        parts.append("\(category)")
        parts.append("\(cuisine)")
        parts.append("\(difficulty)")
        parts.append("\(prepTimeMinutes)")
        parts.append("\(cookTimeMinutes)")
        parts.append("\(servings)")
        parts.append("\(rating)")
        parts.append("\(ingredients)")
        parts.append("\(instructions)")
        parts.append("\(isFavorite)")
        parts.append("\(timesCooked)")
        parts.append("\(caloriesPerServing)")
        parts.append("\(notes)")
        return parts.joined(separator: " | ")
    }
}
