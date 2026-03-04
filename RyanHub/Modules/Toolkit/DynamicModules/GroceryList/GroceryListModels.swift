import Foundation

// MARK: - GroceryList Models

struct GroceryListEntry: Codable, Identifiable {
    var id: String = UUID().uuidString
    var date: String = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: Date())
    }()
    var itemName: String
    var quantity: String
    var category: String
    var isChecked: Bool
    var note: String?

    /// One-line summary for context injection.
    var summaryLine: String {
        var parts: [String] = [date]
        parts.append(itemName)
            parts.append(quantity)
            parts.append(category)
            parts.append("\(isChecked)")
        return parts.joined(separator: " | ")
    }
}
