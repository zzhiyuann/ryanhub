import Foundation

@Observable
@MainActor
final class ReadingTrackerViewModel {

    var entries: [ReadingTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    var dailyPageGoal: Int = ReadingTrackerConstants.defaultDailyPageGoal
    var yearlyBookGoal: Int = ReadingTrackerConstants.defaultYearlyBookGoal

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() {
        Task { await loadData() }
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([ReadingTrackerEntry].self, from: data)
            entries = decoded.sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
            UserDefaults.standard.set(data, forKey: "dynamic_module_readingTracker_cache")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addEntry(_ entry: ReadingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data/add") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteEntry(_ entry: ReadingTrackerEntry) async {
        guard let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data?id=\(entry.id)") else { return }
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Date Helpers

    private var calendar: Calendar { Calendar.current }

    private var today: Date { calendar.startOfDay(for: Date()) }

    var todayEntries: [ReadingTrackerEntry] {
        entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return calendar.isDate(d, inSameDayAs: Date())
        }
    }

    private func entries(in days: Int) -> [ReadingTrackerEntry] {
        let cutoff = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        return entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= cutoff
        }
    }

    // MARK: - Today

    var todayPagesRead: Int {
        todayEntries.reduce(0) { $0 + $1.pagesRead }
    }

    var todayReadingMinutes: Int {
        todayEntries.reduce(0) { $0 + $1.readingMinutes }
    }

    // MARK: - Streak

    private func readingDays() -> Set<String> {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var days = Set<String>()
        for entry in entries where entry.pagesRead > 0 {
            days.insert(entry.dateOnly)
        }
        return days
    }

    var currentStreak: Int {
        let days = readingDays()
        var streak = 0
        var cursor = today
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        // Allow streak to start from yesterday if today has no reading yet
        if !days.contains(fmt.string(from: cursor)) {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }

        while days.contains(fmt.string(from: cursor)) {
            streak += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return streak
    }

    var longestStreak: Int {
        let days = readingDays()
        guard !days.isEmpty else { return 0 }

        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        let sortedDates = days.compactMap { fmt.date(from: $0) }.sorted()
        var longest = 1
        var current = 1

        for i in 1..<sortedDates.count {
            let prev = sortedDates[i - 1]
            let curr = sortedDates[i]
            let diff = calendar.dateComponents([.day], from: prev, to: curr).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Books

    var booksInProgress: [(title: String, author: String, currentPage: Int, totalPages: Int, progressPercent: Double)] {
        // Group entries by bookTitle, find latest entry per book where status == .reading
        var latestByTitle: [String: ReadingTrackerEntry] = [:]
        for entry in entries {
            let key = entry.bookTitle.lowercased()
            if entry.status == .reading {
                if let existing = latestByTitle[key] {
                    if (entry.parsedDate ?? .distantPast) > (existing.parsedDate ?? .distantPast) {
                        latestByTitle[key] = entry
                    }
                } else {
                    latestByTitle[key] = entry
                }
            }
        }
        // Exclude books that have a more recent completed/abandoned entry
        var completedOrAbandoned = Set<String>()
        for entry in entries where entry.status == .completed || entry.status == .abandoned {
            let key = entry.bookTitle.lowercased()
            if let inProgress = latestByTitle[key] {
                if (entry.parsedDate ?? .distantPast) > (inProgress.parsedDate ?? .distantPast) {
                    completedOrAbandoned.insert(key)
                }
            }
        }

        return latestByTitle
            .filter { !completedOrAbandoned.contains($0.key) && !$0.value.bookTitle.isEmpty }
            .map { _, entry in
                let pct = entry.totalPages > 0
                    ? min(1.0, Double(entry.currentPage) / Double(entry.totalPages))
                    : 0.0
                return (
                    title: entry.bookTitle,
                    author: entry.author,
                    currentPage: entry.currentPage,
                    totalPages: entry.totalPages,
                    progressPercent: pct
                )
            }
            .sorted { $0.title < $1.title }
    }

    var currentlyReading: [ReadingBookProgress] {
        var latestByTitle: [String: ReadingTrackerEntry] = [:]
        for entry in entries where entry.status == .reading {
            let key = entry.bookTitle.lowercased()
            if let existing = latestByTitle[key] {
                if (entry.parsedDate ?? .distantPast) > (existing.parsedDate ?? .distantPast) {
                    latestByTitle[key] = entry
                }
            } else {
                latestByTitle[key] = entry
            }
        }
        var completedOrAbandoned = Set<String>()
        for entry in entries where entry.status == .completed || entry.status == .abandoned {
            let key = entry.bookTitle.lowercased()
            if let inProgress = latestByTitle[key],
               (entry.parsedDate ?? .distantPast) > (inProgress.parsedDate ?? .distantPast) {
                completedOrAbandoned.insert(key)
            }
        }
        return latestByTitle
            .filter { !completedOrAbandoned.contains($0.key) && !$0.value.bookTitle.isEmpty }
            .map { _, entry in
                let pct = entry.totalPages > 0
                    ? min(1.0, Double(entry.currentPage) / Double(entry.totalPages))
                    : 0.0
                return ReadingBookProgress(
                    id: entry.id,
                    title: entry.bookTitle,
                    author: entry.author,
                    currentPage: entry.currentPage,
                    totalPages: entry.totalPages,
                    progressPercent: pct,
                    genre: entry.genre,
                    lastSessionDate: entry.parsedDate
                )
            }
            .sorted { $0.title < $1.title }
    }

    var isActiveToday: Bool { !todayEntries.isEmpty }

    var totalBooksCompleted: Int {
        var completedTitles = Set<String>()
        for entry in entries where entry.status == .completed && !entry.bookTitle.isEmpty {
            completedTitles.insert(entry.bookTitle.lowercased())
        }
        return completedTitles.count
    }

    var booksThisYear: Int { booksCompletedThisYear }

    var calendarData: [Date: Double] {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        var map: [Date: Double] = [:]
        for entry in entries {
            if let d = fmt.date(from: entry.dateOnly) {
                let day = Calendar.current.startOfDay(for: d)
                map[day, default: 0] += Double(entry.pagesRead)
            }
        }
        return map
    }

    var booksCompletedThisYear: Int {
        let year = calendar.component(.year, from: Date())
        var completedTitles = Set<String>()
        for entry in entries where entry.status == .completed {
            guard let d = entry.parsedDate else { continue }
            if calendar.component(.year, from: d) == year, !entry.bookTitle.isEmpty {
                completedTitles.insert(entry.bookTitle.lowercased())
            }
        }
        return completedTitles.count
    }

    // MARK: - Aggregates

    var weeklyPagesRead: Int {
        entries(in: 7).reduce(0) { $0 + $1.pagesRead }
    }

    var averagePagesPerDay: Double {
        let total = entries(in: 30).reduce(0) { $0 + $1.pagesRead }
        return Double(total) / 30.0
    }

    var dailyGoalProgress: Double {
        guard dailyPageGoal > 0 else { return 0 }
        return min(1.0, Double(todayPagesRead) / Double(dailyPageGoal))
    }

    var yearlyGoalProgress: Double {
        guard yearlyBookGoal > 0 else { return 0 }
        return Double(booksCompletedThisYear) / Double(yearlyBookGoal)
    }

    // MARK: - Chart Data

    var weeklyPagesTrend: [(date: Date, pages: Int)] {
        (0..<7).map { offset -> (date: Date, pages: Int) in
            let day = calendar.date(byAdding: .day, value: -(6 - offset), to: today) ?? today
            let total = entries.filter { entry in
                guard let d = entry.parsedDate else { return false }
                return calendar.isDate(d, inSameDayAs: day)
            }.reduce(0) { $0 + $1.pagesRead }
            return (date: day, pages: total)
        }
    }

    var monthlyBooksChart: [(month: String, count: Int)] {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM yyyy"
        let shortFmt = DateFormatter()
        shortFmt.dateFormat = "MMM"

        return (0..<12).map { offset -> (month: String, count: Int) in
            let monthDate = calendar.date(byAdding: .month, value: -(11 - offset), to: today) ?? today
            let targetYear = calendar.component(.year, from: monthDate)
            let targetMonth = calendar.component(.month, from: monthDate)

            var completedTitles = Set<String>()
            for entry in entries where entry.status == .completed {
                guard let d = entry.parsedDate else { continue }
                if calendar.component(.year, from: d) == targetYear &&
                   calendar.component(.month, from: d) == targetMonth &&
                   !entry.bookTitle.isEmpty {
                    completedTitles.insert(entry.bookTitle.lowercased())
                }
            }
            return (month: shortFmt.string(from: monthDate), count: completedTitles.count)
        }
    }

    var genreDistribution: [(genre: String, count: Int)] {
        var counts: [String: Set<String>] = [:]
        let year = calendar.component(.year, from: Date())
        for entry in entries where entry.status == .completed {
            guard let d = entry.parsedDate else { continue }
            guard calendar.component(.year, from: d) == year else { continue }
            let key = entry.genre.displayName
            counts[key, default: []].insert(entry.bookTitle.lowercased())
        }
        return counts.map { (genre: $0.key, count: $0.value.count) }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }

    // MARK: - Pace

    private func avgPagesPerDay(daysAgo startOffset: Int, count: Int) -> Double {
        let start = calendar.date(byAdding: .day, value: -startOffset, to: today) ?? today
        let end = calendar.date(byAdding: .day, value: -(startOffset - count), to: today) ?? today
        let total = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= start && d < end
        }.reduce(0) { $0 + $1.pagesRead }
        return Double(total) / Double(count)
    }

    var readingPaceTrend: Double {
        let thisWeek = avgPagesPerDay(daysAgo: 7, count: 7)
        let lastWeek = avgPagesPerDay(daysAgo: 14, count: 7)
        guard lastWeek > 0 else { return thisWeek > 0 ? 2.0 : 1.0 }
        return thisWeek / lastWeek
    }

    var estimatedCompletionDays: [(title: String, daysRemaining: Int)] {
        booksInProgress.compactMap { book in
            guard book.totalPages > 0, book.currentPage < book.totalPages else { return nil }
            let pagesLeft = book.totalPages - book.currentPage

            // 7-day avg for this specific book
            let cutoff = calendar.date(byAdding: .day, value: -7, to: today) ?? today
            let bookEntries = entries.filter { entry in
                guard let d = entry.parsedDate else { return false }
                return entry.bookTitle.lowercased() == book.title.lowercased()
                    && entry.pagesRead > 0
                    && d >= cutoff
            }
            let sevenDayTotal = bookEntries.reduce(0) { $0 + $1.pagesRead }
            let avgPerDay = Double(sevenDayTotal) / 7.0

            guard avgPerDay > 0 else { return nil }
            let days = Int(ceil(Double(pagesLeft) / avgPerDay))
            return (title: book.title, daysRemaining: days)
        }
    }

    // MARK: - Insights

    var readingInsights: [String] {
        var insights: [String] = []
        let cal = calendar

        // Streak milestones
        let streak = currentStreak
        if ReadingTrackerConstants.streakMilestones.contains(streak) {
            insights.append("🔥 \(streak)-day reading streak! Keep it going!")
        } else if streak > 0 {
            let next = ReadingTrackerConstants.streakMilestones.first { $0 > streak }
            if let next = next {
                insights.append("You're on a \(streak)-day streak — \(next - streak) more days to hit \(next)!")
            }
        }

        // Pace comparison
        let thisWeekAvg = avgPagesPerDay(daysAgo: 7, count: 7)
        let lastWeekAvg = avgPagesPerDay(daysAgo: 14, count: 7)
        if lastWeekAvg > 0 && thisWeekAvg > 0 {
            let pct = Int(((thisWeekAvg - lastWeekAvg) / lastWeekAvg) * 100)
            if pct >= 10 {
                insights.append("📈 You read \(pct)% more pages this week vs last week.")
            } else if pct <= -10 {
                insights.append("📉 Reading pace dipped — \(Int(thisWeekAvg)) pages/day vs \(Int(lastWeekAvg)) last week.")
            }
        }

        // Completion predictions
        let today30 = Date()
        for est in estimatedCompletionDays {
            let targetDate = cal.date(byAdding: .day, value: est.daysRemaining, to: today30) ?? today30
            let fmt = DateFormatter()
            fmt.dateFormat = "MMM d"
            insights.append("📖 At your current pace, you'll finish \"\(est.title)\" in ~\(est.daysRemaining) days (around \(fmt.string(from: targetDate))).")
        }

        // Yearly goal tracking
        let completed = booksCompletedThisYear
        let yearProgress = yearlyGoalProgress
        let monthsElapsed = max(1, cal.component(.month, from: Date()))
        let expectedByNow = Int(ceil(Double(yearlyBookGoal) / 12.0 * Double(monthsElapsed)))
        let diff = completed - expectedByNow
        if diff >= 2 {
            insights.append("🎯 You've completed \(completed) of \(yearlyBookGoal) books — \(diff) books ahead of schedule!")
        } else if diff < -1 {
            let monthsLeft = max(1, 12 - monthsElapsed)
            let needed = Double(yearlyBookGoal - completed) / Double(monthsLeft)
            insights.append("⚠️ \(abs(diff)) book(s) behind pace — need ~\(String(format: "%.1f", needed)) books/month to hit your yearly goal.")
        } else if yearProgress >= 1.0 {
            insights.append("🏆 You've hit your yearly reading goal of \(yearlyBookGoal) books!")
        }

        // Genre diversity
        let totalGenres = BookGenre.allCases.count
        let exploredGenres = Set(genreDistribution.map { $0.genre }).count
        if exploredGenres > 0, let topGenre = genreDistribution.first {
            let totalCompleted = genreDistribution.reduce(0) { $0 + $1.count }
            let topPct = totalCompleted > 0 ? Int(Double(topGenre.count) / Double(totalCompleted) * 100) : 0
            insights.append("📚 You've explored \(exploredGenres) of \(totalGenres) genres this year. Most-read: \(topGenre.genre) (\(topPct)%).")
        }

        // Daily personal record
        let dayTotals = Dictionary(grouping: entries.filter { $0.pagesRead > 0 }, by: { $0.dateOnly })
            .mapValues { $0.reduce(0) { $0 + $1.pagesRead } }
        if let record = dayTotals.max(by: { $0.value < $1.value }) {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            if let recordDate = fmt.date(from: record.key) {
                let dayFmt = DateFormatter()
                dayFmt.dateFormat = "EEEE"
                insights.append("🌟 Personal record: \(record.value) pages on \(dayFmt.string(from: recordDate))!")
            }
        }

        // Weekend vs weekday consistency
        let weekdayEntries = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            let weekday = cal.component(.weekday, from: d)
            return weekday >= 2 && weekday <= 6
        }
        let weekendEntries = entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            let weekday = cal.component(.weekday, from: d)
            return weekday == 1 || weekday == 7
        }
        let weekdayDays = Set(weekdayEntries.map { $0.dateOnly }).count
        let weekendDays = Set(weekendEntries.map { $0.dateOnly }).count
        if weekdayDays > 0 && weekendDays > 0 {
            let wdAvg = weekdayEntries.reduce(0) { $0 + $1.pagesRead } / weekdayDays
            let weAvg = weekendEntries.reduce(0) { $0 + $1.pagesRead } / weekendDays
            if weAvg > wdAvg + 5 {
                insights.append("🗓 You average \(weAvg) pages on weekends vs \(wdAvg) on weekdays — weekends are your power reading time!")
            } else if wdAvg > weAvg + 5 {
                insights.append("🗓 You average \(wdAvg) pages on weekdays vs \(weAvg) on weekends — you read more consistently during the week.")
            }
        }

        // Book velocity
        let yearInt = cal.component(.year, from: Date())
        var completedThisYear: [String: [ReadingTrackerEntry]] = [:]
        for entry in entries where entry.status == .completed {
            guard let d = entry.parsedDate, cal.component(.year, from: d) == yearInt else { continue }
            completedThisYear[entry.bookTitle.lowercased(), default: []].append(entry)
        }
        if completedThisYear.count >= 2 {
            insights.append("📊 You're completing about \(completedThisYear.count) books so far this year.")
        }

        // Daily goal encouragement
        if todayPagesRead > 0 && dailyGoalProgress < 1.0 {
            let remaining = dailyPageGoal - todayPagesRead
            insights.append("💪 \(remaining) more pages to hit today's goal of \(dailyPageGoal) pages!")
        } else if dailyGoalProgress >= 1.0 && dailyPageGoal > 0 {
            insights.append("✅ Daily goal achieved! You've read \(todayPagesRead) pages today.")
        }

        return insights
    }

    // MARK: - Chart Data Points

    var weeklyChartData: [ChartDataPoint] {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE"
        return weeklyPagesTrend.map { point in
            ChartDataPoint(label: fmt.string(from: point.date), value: Double(point.pages))
        }
    }

    var monthlyBooksChartData: [ChartDataPoint] {
        monthlyBooksChart.map { ChartDataPoint(label: $0.month, value: Double($0.count)) }
    }

    var genreChartData: [ChartDataPoint] {
        genreDistribution.map { ChartDataPoint(label: $0.genre, value: Double($0.count)) }
    }

    // MARK: - Module Insights

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        let streak = currentStreak
        if ReadingTrackerConstants.streakMilestones.contains(streak) {
            result.append(ModuleInsight(type: .achievement, title: "\(streak)-Day Streak!", message: "You've been reading every day for \(streak) days. Amazing consistency!"))
        }

        if readingPaceTrend >= 1.1 {
            let pct = Int((readingPaceTrend - 1.0) * 100)
            result.append(ModuleInsight(type: .trend, title: "Pace Improving", message: "You're reading \(pct)% more pages per day than last week."))
        } else if readingPaceTrend < 0.9 && readingPaceTrend > 0 {
            let pct = Int((1.0 - readingPaceTrend) * 100)
            result.append(ModuleInsight(type: .warning, title: "Pace Slowing", message: "Reading pace dropped \(pct)% compared to last week."))
        }

        if dailyGoalProgress >= 1.0 {
            result.append(ModuleInsight(type: .achievement, title: "Daily Goal Met!", message: "You've read \(todayPagesRead) pages today — goal achieved!"))
        } else if todayPagesRead == 0 {
            result.append(ModuleInsight(type: .suggestion, title: "Start Reading Today", message: "Log a reading session to keep your streak alive."))
        }

        if yearlyGoalProgress >= 1.0 {
            result.append(ModuleInsight(type: .achievement, title: "Yearly Goal Complete!", message: "You've finished \(booksCompletedThisYear) books this year!"))
        }

        for est in estimatedCompletionDays.prefix(2) {
            result.append(ModuleInsight(type: .trend, title: "Completion Forecast", message: "\"\\(est.title)\" — ~\(est.daysRemaining) days remaining at current pace."))
        }

        return result
    }
}