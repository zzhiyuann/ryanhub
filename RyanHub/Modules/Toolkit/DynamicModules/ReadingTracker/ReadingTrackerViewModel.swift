import Foundation

// MARK: - ReadingTrackerViewModel

@Observable
@MainActor
final class ReadingTrackerViewModel {

    // MARK: - State

    var entries: [ReadingTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    // MARK: - User Settings

    var dailyGoal: Int = 30
    var yearlyGoal: Int = 24

    // MARK: - UI State

    var selectedTab: ReadingTab = .nowReading
    var searchText: String = ""
    var selectedBook: ReadingTrackerEntry?
    var showingAddSheet = false
    var showingBookDetail = false

    enum ReadingTab: String, CaseIterable, Identifiable {
        case nowReading = "Now Reading"
        case library = "Library"
        case stats = "Stats"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .nowReading: return "book.fill"
            case .library: return "books.vertical.fill"
            case .stats: return "chart.bar.fill"
            }
        }
    }

    // MARK: - Bridge Server

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    private let moduleId = "readingTracker"

    // MARK: - Init

    init() {
        loadCachedData()
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil

        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data") else {
                errorMessage = "Invalid URL"
                isLoading = false
                return
            }

            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                errorMessage = "Server error"
                isLoading = false
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([ReadingTrackerEntry].self, from: data)
            cacheData()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func addEntry(_ entry: ReadingTrackerEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data/add") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            request.httpBody = try encoder.encode(entry)

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                entries.append(entry)
                cacheData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: ReadingTrackerEntry) async {
        do {
            guard let url = URL(string: "\(bridgeBaseURL)/modules/\(moduleId)/data?id=\(entry.id)") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"

            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                entries.removeAll { $0.id == entry.id }
                cacheData()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateEntry(_ entry: ReadingTrackerEntry) async {
        await deleteEntry(entry)
        await addEntry(entry)
    }

    // MARK: - Quick Actions

    func updateCurrentPage(for entry: ReadingTrackerEntry, to page: Int) async {
        var updated = entry
        updated.currentPage = min(max(page, 0), entry.totalPages)
        updated.lastReadDate = Date()

        if updated.currentPage >= updated.totalPages && updated.status == .reading {
            updated.status = .finished
            updated.finishedReading = Date()
        }

        await updateEntry(updated)
    }

    func changeStatus(for entry: ReadingTrackerEntry, to status: ReadingStatus) async {
        var updated = entry
        updated.status = status

        switch status {
        case .reading:
            if entry.status == .wantToRead {
                updated.startedReading = Date()
            }
            updated.lastReadDate = Date()
        case .finished:
            updated.finishedReading = Date()
            updated.currentPage = entry.totalPages
            updated.lastReadDate = Date()
        case .abandoned:
            updated.lastReadDate = Date()
        case .wantToRead:
            break
        }

        await updateEntry(updated)
    }

    func updateRating(for entry: ReadingTrackerEntry, to rating: Int) async {
        var updated = entry
        updated.rating = min(max(rating, 0), 5)
        await updateEntry(updated)
    }

    // MARK: - Filtered Lists (Computed Properties from Spec)

    var currentlyReading: [ReadingTrackerEntry] {
        entries
            .filter { $0.status == .reading }
            .sorted { $0.lastReadDate > $1.lastReadDate }
    }

    var wantToReadBooks: [ReadingTrackerEntry] {
        entries
            .filter { $0.status == .wantToRead }
            .sorted { $0.parsedDate < $1.parsedDate }
    }

    var finishedBooks: [ReadingTrackerEntry] {
        entries
            .filter { $0.status == .finished }
            .sorted {
                ($0.finishedReading ?? .distantPast) > ($1.finishedReading ?? .distantPast)
            }
    }

    var abandonedBooks: [ReadingTrackerEntry] {
        entries.filter { $0.status == .abandoned }
    }

    // MARK: - Yearly Stats

    var booksFinishedThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        return finishedBooks.filter { entry in
            guard let finished = entry.finishedReading else { return false }
            return Calendar.current.component(.year, from: finished) == year
        }.count
    }

    var totalPagesReadThisYear: Int {
        let year = Calendar.current.component(.year, from: Date())
        let finishedPages = finishedBooks
            .filter { entry in
                guard let finished = entry.finishedReading else { return false }
                return Calendar.current.component(.year, from: finished) == year
            }
            .reduce(0) { $0 + $1.totalPages }

        let currentPages = currentlyReading.reduce(0) { $0 + $1.currentPage }

        return finishedPages + currentPages
    }

    var yearlyGoalProgress: Double {
        guard yearlyGoal > 0 else { return 0 }
        return min(Double(booksFinishedThisYear) / Double(yearlyGoal), 1.0)
    }

    // MARK: - Streak

    var readingStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        while true {
            let dayMatches = entries.contains { entry in
                entry.status == .reading || entry.status == .finished
            } && entries.contains { entry in
                calendar.isDate(entry.lastReadDate, inSameDayAs: checkDate)
            }

            if dayMatches {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    var longestStreak: Int {
        guard !entries.isEmpty else { return 0 }

        let calendar = Calendar.current
        let readDates = Set(entries.map { calendar.startOfDay(for: $0.lastReadDate) })
        let sortedDates = readDates.sorted(by: >)

        guard !sortedDates.isEmpty else { return 0 }

        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let diff = calendar.dateComponents([.day], from: sortedDates[i], to: sortedDates[i - 1])
            if diff.day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }

    // MARK: - Ratings & Genre

    var averageRating: Double {
        let ratedBooks = finishedBooks.filter { $0.rating > 0 }
        guard !ratedBooks.isEmpty else { return 0 }
        return Double(ratedBooks.reduce(0) { $0 + $1.rating }) / Double(ratedBooks.count)
    }

    var genreBreakdown: [(BookGenre, Int)] {
        var counts: [BookGenre: Int] = [:]
        for entry in finishedBooks {
            counts[entry.genre, default: 0] += 1
        }
        return counts.sorted { $0.value > $1.value }
    }

    var monthlyFinished: [Int] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: Date())
        var months = Array(repeating: 0, count: 12)

        for entry in finishedBooks {
            guard let finished = entry.finishedReading else { continue }
            let components = calendar.dateComponents([.year, .month], from: finished)
            if components.year == year, let month = components.month, month >= 1, month <= 12 {
                months[month - 1] += 1
            }
        }

        return months
    }

    // MARK: - Progress

    func progressPercent(for entry: ReadingTrackerEntry) -> Double {
        guard entry.totalPages > 0 else { return 0 }
        return min(max(Double(entry.currentPage) / Double(entry.totalPages) * 100.0, 0), 100)
    }

    // MARK: - Search / Filter

    var filteredEntries: [ReadingTrackerEntry] {
        guard !searchText.isEmpty else { return entries }
        let query = searchText.lowercased()
        return entries.filter {
            $0.title.lowercased().contains(query) ||
            $0.author.lowercased().contains(query) ||
            $0.genre.displayName.lowercased().contains(query)
        }
    }

    var filteredCurrentlyReading: [ReadingTrackerEntry] {
        guard !searchText.isEmpty else { return currentlyReading }
        return currentlyReading.filter { matchesSearch($0) }
    }

    var filteredWantToRead: [ReadingTrackerEntry] {
        guard !searchText.isEmpty else { return wantToReadBooks }
        return wantToReadBooks.filter { matchesSearch($0) }
    }

    var filteredFinished: [ReadingTrackerEntry] {
        guard !searchText.isEmpty else { return finishedBooks }
        return finishedBooks.filter { matchesSearch($0) }
    }

    var filteredAbandoned: [ReadingTrackerEntry] {
        guard !searchText.isEmpty else { return abandonedBooks }
        return abandonedBooks.filter { matchesSearch($0) }
    }

    private func matchesSearch(_ entry: ReadingTrackerEntry) -> Bool {
        let query = searchText.lowercased()
        return entry.title.lowercased().contains(query) ||
               entry.author.lowercased().contains(query) ||
               entry.genre.displayName.lowercased().contains(query)
    }

    // MARK: - Date Helpers

    var todayEntries: [ReadingTrackerEntry] {
        let today = Date()
        return entries.filter {
            Calendar.current.isDate($0.lastReadDate, inSameDayAs: today)
        }
    }

    var weekEntries: [ReadingTrackerEntry] {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return [] }
        return entries.filter { $0.lastReadDate >= weekAgo }
    }

    var todayPagesRead: Int {
        todayEntries.reduce(0) { $0 + $1.currentPage }
    }

    var dailyGoalProgress: Double {
        guard dailyGoal > 0 else { return 0 }
        return min(Double(todayPagesRead) / Double(dailyGoal), 1.0)
    }

    // MARK: - Trend Analysis

    var paceStatus: String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        guard month > 0 else { return "On track" }
        let currentPace = Double(booksFinishedThisYear) / Double(month)
        let neededPace = Double(yearlyGoal) / 12.0

        if currentPace >= neededPace {
            return "On track"
        } else if currentPace >= neededPace * 0.75 {
            return "Slightly behind"
        } else {
            return "Behind pace"
        }
    }

    var projectedYearlyFinish: Int {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: Date())
        guard month > 0 else { return 0 }
        let monthlyRate = Double(booksFinishedThisYear) / Double(month)
        return Int(monthlyRate * 12.0)
    }

    var averageDaysToFinish: Double {
        let finished = finishedBooks.filter { $0.finishedReading != nil }
        guard !finished.isEmpty else { return 0 }
        let totalDays = finished.reduce(0) { $0 + $1.daysReading }
        return Double(totalDays) / Double(finished.count)
    }

    var rollingSevenDayPagesPerDay: Double {
        let calendar = Calendar.current
        guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else { return 0 }
        let recentEntries = entries.filter { $0.lastReadDate >= weekAgo && ($0.status == .reading || $0.status == .finished) }
        let totalPages = recentEntries.reduce(0) { $0 + $1.currentPage }
        return Double(totalPages) / 7.0
    }

    var mostReadGenre: (genre: BookGenre, percentage: Double)? {
        guard let top = genreBreakdown.first, !finishedBooks.isEmpty else { return nil }
        let percentage = Double(top.1) / Double(finishedBooks.count) * 100.0
        return (top.0, percentage)
    }

    var abandonedRate: Double {
        let started = entries.filter { $0.status != .wantToRead }
        guard !started.isEmpty else { return 0 }
        let abandoned = started.filter { $0.status == .abandoned }
        return Double(abandoned.count) / Double(started.count) * 100.0
    }

    // MARK: - Chart Data

    var monthlyFinishedChartData: [ChartDataPoint] {
        let monthNames = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        return zip(monthNames, monthlyFinished).map { ChartDataPoint(label: $0, value: Double($1)) }
    }

    var genreChartData: [ChartDataPoint] {
        genreBreakdown.map { ChartDataPoint(label: $0.0.displayName, value: Double($0.1)) }
    }

    var yearlyGoalChartData: [ChartDataPoint] {
        [
            ChartDataPoint(label: "Finished", value: Double(booksFinishedThisYear)),
            ChartDataPoint(label: "Remaining", value: Double(max(yearlyGoal - booksFinishedThisYear, 0)))
        ]
    }

    // MARK: - Insights

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        // Yearly goal pace
        if booksFinishedThisYear > 0 {
            let status = paceStatus
            let projected = projectedYearlyFinish
            let type: InsightType = status == "On track" ? .achievement : .warning
            result.append(ModuleInsight(
                type: type,
                title: status,
                message: "You've finished \(booksFinishedThisYear) of \(yearlyGoal) books this year. At this pace, you'll finish ~\(projected) by year end."
            ))
        }

        // Average finish time
        if averageDaysToFinish > 0 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Reading Speed",
                message: "You finish a book in \(Int(averageDaysToFinish)) days on average."
            ))
        }

        // Most-read genre
        if let topGenre = mostReadGenre {
            result.append(ModuleInsight(
                type: .trend,
                title: "Favorite Genre",
                message: "\(topGenre.genre.displayName) makes up \(Int(topGenre.percentage))% of your library."
            ))
        }

        // Reading velocity
        let velocity = rollingSevenDayPagesPerDay
        if velocity > 0 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Reading Velocity",
                message: "You're averaging \(Int(velocity)) pages/day over the last 7 days."
            ))
        }

        // Streak
        let streak = readingStreak
        let best = longestStreak
        if streak > 0 {
            if streak >= best && streak > 1 {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "Streak Record!",
                    message: "Your current \(streak)-day streak is your all-time best!"
                ))
            } else {
                result.append(ModuleInsight(
                    type: .achievement,
                    title: "\(streak)-Day Streak",
                    message: "Keep reading daily! Your best streak is \(best) days."
                ))
            }
        } else {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Start a Streak",
                message: "Read today to start building a daily reading habit."
            ))
        }

        // Abandoned rate
        let rate = abandonedRate
        if rate > 25 {
            result.append(ModuleInsight(
                type: .warning,
                title: "High Abandon Rate",
                message: "\(Int(rate))% of your started books were abandoned. Try shorter books or different genres."
            ))
        }

        // Suggestions
        if currentlyReading.isEmpty && !wantToReadBooks.isEmpty {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Pick Up a Book",
                message: "You have \(wantToReadBooks.count) books in your reading list. Start one today!"
            ))
        }

        if entries.isEmpty {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Get Started",
                message: "Add your first book to begin tracking your reading journey."
            ))
        }

        return result
    }

    // MARK: - Caching

    private func cacheData() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(entries)
            UserDefaults.standard.set(data, forKey: "dynamic_module_\(moduleId)_cache")
        } catch {
            // Cache failure is non-critical
        }
    }

    private func loadCachedData() {
        guard let data = UserDefaults.standard.data(forKey: "dynamic_module_\(moduleId)_cache") else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            entries = try decoder.decode([ReadingTrackerEntry].self, from: data)
        } catch {
            // Cache load failure is non-critical
        }
    }
}