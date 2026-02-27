import Foundation

// MARK: - Health View Model

/// Manages health tracking data including weight, food, and activity entries.
/// Persists data locally using UserDefaults (JSON encoded) for MVP.
@Observable
final class HealthViewModel {
    // MARK: - State

    var weightEntries: [WeightEntry] = []
    var foodEntries: [FoodEntry] = []
    var activityEntries: [ActivityEntry] = []
    var selectedTab: HealthTab = .weight

    // MARK: - Computed Properties

    /// Most recent weight entry.
    var latestWeight: WeightEntry? {
        weightEntries.sorted { $0.date > $1.date }.first
    }

    /// Last 7 weight entries for the mini chart, sorted oldest to newest.
    var weeklyWeights: [WeightEntry] {
        Array(weightEntries.sorted { $0.date < $1.date }.suffix(7))
    }

    /// Last 30 weight entries for the full timeline chart, sorted oldest to newest.
    var timelineWeights: [WeightEntry] {
        Array(weightEntries.sorted { $0.date < $1.date }.suffix(30))
    }

    /// Weight range for the timeline chart (min, max).
    var weightRange: (min: Double, max: Double)? {
        let weights = timelineWeights.map(\.weight)
        guard let minW = weights.min(), let maxW = weights.max() else { return nil }
        // Add padding for visual comfort
        let padding = max((maxW - minW) * 0.1, 0.5)
        return (min: minW - padding, max: maxW + padding)
    }

    /// Weight change from the first to last entry in the weekly data.
    var weeklyWeightChange: Double? {
        guard let first = weeklyWeights.first,
              let last = weeklyWeights.last,
              first.id != last.id else {
            return nil
        }
        return last.weight - first.weight
    }

    /// Today's food entries sorted by time.
    var todayFoodEntries: [FoodEntry] {
        let calendar = Calendar.current
        return foodEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    /// Total calories consumed today (only from entries with calorie data).
    var todayCalories: Int {
        todayFoodEntries.compactMap(\.calories).reduce(0, +)
    }

    /// Today's activity entries sorted by time.
    var todayActivityEntries: [ActivityEntry] {
        let calendar = Calendar.current
        return activityEntries
            .filter { calendar.isDateInToday($0.date) }
            .sorted { $0.date < $1.date }
    }

    /// Total activity duration today in minutes.
    var todayActivityMinutes: Int {
        todayActivityEntries.map(\.duration).reduce(0, +)
    }

    /// Total calories burned today from AI-analyzed activities.
    var todayActivityCalories: Int {
        todayActivityEntries.compactMap(\.caloriesBurned).reduce(0, +)
    }

    // MARK: - Init

    init() {
        loadAll()
    }

    // MARK: - Weight Actions

    /// Add a new weight entry.
    func addWeight(weight: Double, date: Date = Date(), note: String? = nil) {
        let entry = WeightEntry(date: date, weight: weight, note: note)
        weightEntries.append(entry)
        save(weightEntries, forKey: StorageKeys.weightEntries)
    }

    /// Delete a weight entry.
    func deleteWeight(_ entry: WeightEntry) {
        weightEntries.removeAll { $0.id == entry.id }
        save(weightEntries, forKey: StorageKeys.weightEntries)
    }

    /// Today's macros totals.
    var todayProtein: Int {
        todayFoodEntries.compactMap(\.protein).reduce(0, +)
    }

    var todayCarbs: Int {
        todayFoodEntries.compactMap(\.carbs).reduce(0, +)
    }

    var todayFat: Int {
        todayFoodEntries.compactMap(\.fat).reduce(0, +)
    }

    // MARK: - Food Actions

    /// Add a new food entry.
    func addFood(mealType: MealType, description: String, calories: Int? = nil, date: Date = Date()) {
        let entry = FoodEntry(date: date, mealType: mealType, description: description, calories: calories)
        foodEntries.append(entry)
        save(foodEntries, forKey: StorageKeys.foodEntries)
    }

    /// Add a food entry from AI analysis result.
    func addFoodFromAnalysis(_ result: FoodAnalysisResult, description: String, date: Date = Date()) {
        let mealType = MealType(rawValue: result.mealType) ?? suggestedMealType()
        let items = result.items.map {
            FoodItem(name: $0.name, calories: $0.calories, protein: $0.protein, carbs: $0.carbs, fat: $0.fat, portion: $0.portion)
        }
        let entry = FoodEntry(
            date: date,
            mealType: mealType,
            description: description,
            calories: result.totalCalories,
            protein: result.totalProtein,
            carbs: result.totalCarbs,
            fat: result.totalFat,
            items: items,
            aiSummary: result.summary,
            isAIAnalyzed: true
        )
        foodEntries.append(entry)
        save(foodEntries, forKey: StorageKeys.foodEntries)
    }

    /// Suggest a meal type based on the current hour.
    func suggestedMealType() -> MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return .breakfast
        case 11..<14: return .lunch
        case 14..<17: return .snack
        default: return .dinner
        }
    }

    /// Delete a food entry.
    func deleteFood(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
        save(foodEntries, forKey: StorageKeys.foodEntries)
    }

    // MARK: - Activity Actions

    /// Add a new activity entry.
    func addActivity(type: String, duration: Int, date: Date = Date(), note: String? = nil, rawDescription: String? = nil) {
        let entry = ActivityEntry(date: date, type: type, duration: duration, note: note, rawDescription: rawDescription)
        activityEntries.append(entry)
        save(activityEntries, forKey: StorageKeys.activityEntries)
    }

    /// Add an activity from AI analysis result.
    func addActivityFromAnalysis(_ result: ActivityAnalysisResult, description: String, date: Date = Date()) {
        let entry = ActivityEntry(
            date: date,
            type: result.type,
            duration: result.duration ?? 0,
            note: result.summary,
            rawDescription: description,
            caloriesBurned: result.caloriesBurned,
            isAIAnalyzed: true,
            exercises: result.exercises ?? [],
            aiSummary: result.summary
        )
        activityEntries.append(entry)
        save(activityEntries, forKey: StorageKeys.activityEntries)
    }

    /// Add an activity from a natural language description.
    /// Parses the text to extract type and duration, then saves the entry.
    func addActivityFromDescription(_ description: String, date: Date = Date()) {
        let result = ActivityParser.parse(description)
        let entry = ActivityEntry(
            date: date,
            type: result.type,
            duration: result.duration ?? 30, // Default to 30 minutes if not detected
            note: result.note,
            rawDescription: description
        )
        activityEntries.append(entry)
        save(activityEntries, forKey: StorageKeys.activityEntries)
    }

    /// Delete an activity entry.
    func deleteActivity(_ entry: ActivityEntry) {
        activityEntries.removeAll { $0.id == entry.id }
        save(activityEntries, forKey: StorageKeys.activityEntries)
    }

    // MARK: - Persistence

    /// Load all data from UserDefaults.
    func loadAll() {
        weightEntries = load(forKey: StorageKeys.weightEntries) ?? []
        foodEntries = load(forKey: StorageKeys.foodEntries) ?? []
        activityEntries = load(forKey: StorageKeys.activityEntries) ?? []
    }

    private func save<T: Encodable>(_ items: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let weightEntries = "ryanhub_health_weight"
        static let foodEntries = "ryanhub_health_food"
        static let activityEntries = "ryanhub_health_activity"
    }
}
