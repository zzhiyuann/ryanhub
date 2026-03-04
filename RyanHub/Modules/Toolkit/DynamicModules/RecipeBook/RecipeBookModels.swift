import Foundation

// MARK: - RecipeBook Models

struct RecipeBookEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var title: String
    var ingredients: String
    var prepTime: Int
    var cookTime: Int
    var servings: Int
    var instructions: String
    var category: String
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(title)
            parts.append(ingredients)
            parts.append("\(prepTime)")
            parts.append("\(cookTime)")
            parts.append("\(servings)")
            parts.append(instructions)
            parts.append(category)
        return parts.joined(separator: " | ")
    }
}
