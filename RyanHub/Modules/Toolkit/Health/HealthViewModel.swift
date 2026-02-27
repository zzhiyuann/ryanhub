import Foundation
import HealthKit

// MARK: - Health View Model

/// Manages health tracking data including weight, food, and activity entries.
/// Persists data locally using UserDefaults as a cache, with bridge server as source of truth.
@MainActor
@Observable
final class HealthViewModel {
    // MARK: - State

    var weightEntries: [WeightEntry] = []
    var foodEntries: [FoodEntry] = []
    var activityEntries: [ActivityEntry] = []
    var selectedTab: HealthTab = .weight

    // MARK: - HealthKit State

    /// Today's step count from Apple Health.
    var todaySteps: Int = 0

    /// Estimated calories burned from steps (steps * 0.04).
    var stepsCaloriesBurned: Int {
        Int(Double(todaySteps) * 0.04)
    }

    /// Whether HealthKit authorization has been granted.
    var healthKitAuthorized: Bool = false

    /// Whether a HealthKit query is in progress.
    var isLoadingSteps: Bool = false

    /// The HealthKit store instance (nil if HealthKit is unavailable).
    private let healthStore: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil

    // MARK: - Bridge Server

    /// Base URL for the bridge server (same pattern as ParkingViewModel).
    private static var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? AppState.defaultFoodAnalysisURL
    }

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
        foodEntries(for: Date())
    }

    /// Total calories consumed today (only from entries with calorie data).
    var todayCalories: Int {
        todayFoodEntries.compactMap(\.calories).reduce(0, +)
    }

    /// Today's activity entries sorted by time.
    var todayActivityEntries: [ActivityEntry] {
        activityEntries(for: Date())
    }

    /// Total activity duration today in minutes.
    var todayActivityMinutes: Int {
        todayActivityEntries.map(\.duration).reduce(0, +)
    }

    /// Total calories burned today from AI-analyzed activities.
    var todayActivityCalories: Int {
        todayActivityEntries.compactMap(\.caloriesBurned).reduce(0, +)
    }

    // MARK: - Date-Filtered Queries

    /// Food entries for a specific date, sorted by time.
    func foodEntries(for date: Date) -> [FoodEntry] {
        let calendar = Calendar.current
        return foodEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    /// Total calories for a specific date.
    func calories(for date: Date) -> Int {
        foodEntries(for: date).compactMap(\.calories).reduce(0, +)
    }

    /// Total protein for a specific date.
    func protein(for date: Date) -> Int {
        foodEntries(for: date).compactMap(\.protein).reduce(0, +)
    }

    /// Total carbs for a specific date.
    func carbs(for date: Date) -> Int {
        foodEntries(for: date).compactMap(\.carbs).reduce(0, +)
    }

    /// Total fat for a specific date.
    func fat(for date: Date) -> Int {
        foodEntries(for: date).compactMap(\.fat).reduce(0, +)
    }

    /// Activity entries for a specific date, sorted by time.
    func activityEntries(for date: Date) -> [ActivityEntry] {
        let calendar = Calendar.current
        return activityEntries
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    /// Total activity duration for a specific date in minutes.
    func activityMinutes(for date: Date) -> Int {
        activityEntries(for: date).map(\.duration).reduce(0, +)
    }

    /// Total calories burned for a specific date.
    func activityCalories(for date: Date) -> Int {
        activityEntries(for: date).compactMap(\.caloriesBurned).reduce(0, +)
    }

    // MARK: - Init

    init() {
        loadAll()
    }

    // MARK: - HealthKit

    /// Request HealthKit authorization and fetch today's step count.
    func requestHealthKitAccess() {
        guard let healthStore else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let readTypes: Set<HKObjectType> = [stepType]

        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, error in
            Task { @MainActor in
                guard let self else { return }
                if success {
                    self.healthKitAuthorized = true
                    self.fetchTodaySteps()
                } else {
                    print("[HealthVM] HealthKit authorization failed: \(error?.localizedDescription ?? "unknown")")
                }
            }
        }
    }

    /// Fetch today's step count from HealthKit.
    func fetchTodaySteps() {
        guard let healthStore else { return }
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { [weak self] _, result, error in
            Task { @MainActor in
                guard let self else { return }
                self.isLoadingSteps = false
                if let sum = result?.sumQuantity() {
                    self.todaySteps = Int(sum.doubleValue(for: .count()))
                } else {
                    print("[HealthVM] Step query error: \(error?.localizedDescription ?? "no data")")
                }
            }
        }

        isLoadingSteps = true
        healthStore.execute(query)
    }

    // MARK: - Weight Actions

    /// Add a new weight entry.
    func addWeight(weight: Double, date: Date = Date(), note: String? = nil) {
        let entry = WeightEntry(date: date, weight: weight, note: note)
        weightEntries.append(entry)
        saveAndSync(weightEntries, forKey: StorageKeys.weightEntries, endpoint: "/health-data/weight")
    }

    /// Delete a weight entry.
    func deleteWeight(_ entry: WeightEntry) {
        weightEntries.removeAll { $0.id == entry.id }
        saveAndSync(weightEntries, forKey: StorageKeys.weightEntries, endpoint: "/health-data/weight")
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
        saveAndSync(foodEntries, forKey: StorageKeys.foodEntries, endpoint: "/health-data/food")
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
        saveAndSync(foodEntries, forKey: StorageKeys.foodEntries, endpoint: "/health-data/food")
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
        saveAndSync(foodEntries, forKey: StorageKeys.foodEntries, endpoint: "/health-data/food")
    }

    // MARK: - Activity Actions

    /// Add a new activity entry.
    func addActivity(type: String, duration: Int, date: Date = Date(), note: String? = nil, rawDescription: String? = nil) {
        let entry = ActivityEntry(date: date, type: type, duration: duration, note: note, rawDescription: rawDescription)
        activityEntries.append(entry)
        saveAndSync(activityEntries, forKey: StorageKeys.activityEntries, endpoint: "/health-data/activity")
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
        saveAndSync(activityEntries, forKey: StorageKeys.activityEntries, endpoint: "/health-data/activity")
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
        saveAndSync(activityEntries, forKey: StorageKeys.activityEntries, endpoint: "/health-data/activity")
    }

    /// Delete an activity entry.
    func deleteActivity(_ entry: ActivityEntry) {
        activityEntries.removeAll { $0.id == entry.id }
        saveAndSync(activityEntries, forKey: StorageKeys.activityEntries, endpoint: "/health-data/activity")
    }

    // MARK: - Persistence (Local Cache)

    /// Load all data from local cache, then async refresh from server.
    func loadAll() {
        loadFromCache()
        Task { await loadFromServer() }
    }

    /// Load all data from UserDefaults cache (fast, synchronous).
    private func loadFromCache() {
        weightEntries = load(forKey: StorageKeys.weightEntries) ?? []
        foodEntries = load(forKey: StorageKeys.foodEntries) ?? []
        activityEntries = load(forKey: StorageKeys.activityEntries) ?? []
    }

    /// Save to local UserDefaults cache only.
    private func saveLocal<T: Encodable>(_ items: T, forKey key: String) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(items) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Save to local cache AND async sync to bridge server.
    private func saveAndSync<T: Encodable>(_ items: T, forKey key: String, endpoint: String) {
        saveLocal(items, forKey: key)
        Task { await postToServer(items, endpoint: endpoint) }
    }

    private func load<T: Decodable>(forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    // MARK: - Server Sync

    /// Fetch all health data from the bridge server and merge with local cache.
    /// Uses union-by-id so entries from multiple devices are preserved.
    private func loadFromServer() async {
        if let serverWeights: [WeightEntry] = await fetchFromServer(endpoint: "/health-data/weight") {
            weightEntries = mergeById(local: weightEntries, server: serverWeights)
            saveLocal(weightEntries, forKey: StorageKeys.weightEntries)
        }

        if let serverFood: [FoodEntry] = await fetchFromServer(endpoint: "/health-data/food") {
            foodEntries = mergeById(local: foodEntries, server: serverFood)
            saveLocal(foodEntries, forKey: StorageKeys.foodEntries)
        }

        if let serverActivities: [ActivityEntry] = await fetchFromServer(endpoint: "/health-data/activity") {
            activityEntries = mergeById(local: activityEntries, server: serverActivities)
            saveLocal(activityEntries, forKey: StorageKeys.activityEntries)
        }
    }

    /// Merge two arrays by id. Server entries take precedence for duplicates.
    private func mergeById<T: Identifiable & Decodable>(local: [T], server: [T]) -> [T] where T.ID: Hashable {
        var merged: [T.ID: T] = [:]
        for item in local { merged[item.id] = item }
        for item in server { merged[item.id] = item }
        return Array(merged.values)
    }

    /// Generic GET from bridge server, returning decoded JSON or nil on failure.
    private func fetchFromServer<T: Decodable>(endpoint: String) async -> T? {
        guard let url = URL(string: "\(Self.bridgeBaseURL)\(endpoint)") else { return nil }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200..<300).contains(httpResponse.statusCode),
                  !data.isEmpty else {
                return nil
            }
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(T.self, from: data)
        } catch {
            print("[HealthVM] Failed to fetch \(endpoint): \(error.localizedDescription)")
            return nil
        }
    }

    /// Generic POST to bridge server, encoding items as JSON body.
    private func postToServer<T: Encodable>(_ items: T, endpoint: String) async {
        guard let url = URL(string: "\(Self.bridgeBaseURL)\(endpoint)") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(items)
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                print("[HealthVM] Server returned \(httpResponse.statusCode) for POST \(endpoint)")
            }
        } catch {
            print("[HealthVM] Failed to post \(endpoint): \(error.localizedDescription)")
        }
    }

    // MARK: - Storage Keys

    private enum StorageKeys {
        static let weightEntries = "ryanhub_health_weight"
        static let foodEntries = "ryanhub_health_food"
        static let activityEntries = "ryanhub_health_activity"
    }
}
