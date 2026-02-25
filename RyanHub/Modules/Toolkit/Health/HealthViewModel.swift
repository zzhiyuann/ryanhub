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

    // MARK: - Food Actions

    /// Add a new food entry.
    func addFood(mealType: MealType, description: String, calories: Int? = nil, date: Date = Date()) {
        let entry = FoodEntry(date: date, mealType: mealType, description: description, calories: calories)
        foodEntries.append(entry)
        save(foodEntries, forKey: StorageKeys.foodEntries)
    }

    /// Delete a food entry.
    func deleteFood(_ entry: FoodEntry) {
        foodEntries.removeAll { $0.id == entry.id }
        save(foodEntries, forKey: StorageKeys.foodEntries)
    }

    // MARK: - Activity Actions

    /// Add a new activity entry.
    func addActivity(type: String, duration: Int, date: Date = Date(), note: String? = nil) {
        let entry = ActivityEntry(date: date, type: type, duration: duration, note: note)
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
