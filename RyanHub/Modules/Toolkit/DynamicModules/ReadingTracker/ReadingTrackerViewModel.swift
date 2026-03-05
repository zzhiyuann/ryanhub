import Foundation
import SwiftUI

// MARK: - ReadingTracker View Model

@Observable
@MainActor
final class ReadingTrackerViewModel {
    var entries: [ReadingTrackerEntry] = []
    var isLoading = false
    var errorMessage: String?

    private var bridgeBaseURL: String {
        UserDefaults.standard.string(forKey: "ryanhub_server_url")
            .flatMap { URL(string: $0)?.host }
            .map { "http://\($0):18790" }
            ?? "http://localhost:18790"
    }

    init() { Task { await loadData() } }

    // MARK: - Date Helpers

    private var todayString: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df.string(from: Date())
    }

    var todayEntries: [ReadingTrackerEntry] {
        entries.filter { $0.dateOnly == todayString }
    }

    private func isoWeekBounds(offsetWeeks: Int = 0) -> (start: Date, end: Date) {
        let calendar = Calendar(identifier: .iso8601)
        let interval = calendar.dateInterval(of: .weekOfYear, for: Date())!
        let start = calendar.date(byAdding: .weekOfYear, value: offsetWeeks, to: interval.start)!
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
        return (start, end)
    }

    private func pagesInWeek(offsetWeeks: Int) -> Int {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let (start, end) = isoWeekBounds(offsetWeeks: offsetWeeks)
        return entries.filter {
            guard let d = df.date(from: $0.dateOnly) else { return false }
            return d >= start && d < end
        }.reduce(0) { $0 + $1.pagesRead }
    }

    // MARK: - Currently Reading Books

    var currentlyReadingBooks: [(title: String, author: String, currentPage: Int, totalPages: Int, progressPercent: Double)] {
        var latestByTitle: [String: ReadingTrackerEntry] = [:]
        for entry in entries where entry.status == .currentlyReading && !entry.bookTitle.isEmpty {
            if let existing = latestByTitle[entry.bookTitle] {
                if entry.date > existing.date { latestByTitle[entry.bookTitle] = entry }
            } else {
                latestByTitle[entry.bookTitle] = entry
            }
        }
        return latestByTitle.values.sorted { $0.bookTitle < $1.bookTitle }.map {
            (title: $0.bookTitle, author: $0.author, currentPage: $0.currentPage,
             totalPages: $0.totalPages, progressPercent: $0.progressPercent)
        }
    }

    // MARK: - Today Totals

    var totalPagesReadToday: Int {
        todayEntries.reduce(0) { $0 + $1.pagesRead }
    }

    var totalMinutesReadToday: Int {
        todayEntries.reduce(0) { $0 + $1.minutesRead }
    }

    // MARK: - Books Finished

    var booksFinishedCount: Int {
        Set(entries.filter { $0.status == .finished && !$0.bookTitle.isEmpty }.map { $0.bookTitle }).count
    }

    private var booksFinishedThisYear: Int {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let finished = entries.filter { entry in
            guard entry.status == .finished, !entry.bookTitle.isEmpty,
                  let d = df.date(from: entry.dateOnly) else { return false }
            return calendar.component(.year, from: d) == currentYear
        }
        return Set(finished.map { $0.bookTitle }).count
    }

    // MARK: - Streaks

    var currentStreak: Int {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let activeDays = Set(
            entries.filter { $0.pagesRead > 0 }
                .compactMap { df.date(from: $0.dateOnly) }
                .map { calendar.startOfDay(for: $0) }
        )
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        guard activeDays.contains(today) || activeDays.contains(yesterday) else { return 0 }
        var day = activeDays.contains(today) ? today : yesterday
        var streak = 0
        while activeDays.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let unique = Array(Set(
            entries.filter { $0.pagesRead > 0 }
                .compactMap { df.date(from: $0.dateOnly) }
                .map { calendar.startOfDay(for: $0) }
        )).sorted()
        guard !unique.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<unique.count {
            if calendar.dateComponents([.day], from: unique[i - 1], to: unique[i]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    // MARK: - Weekly Stats

    var weeklyPagesRead: Int { pagesInWeek(offsetWeeks: 0) }

    var weeklyReadingTrend: [(day: String, pages: Int)] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "EEE"
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: Date())!
            let dayStr = df.string(from: date)
            let pages = entries.filter { $0.dateOnly == dayStr }.reduce(0) { $0 + $1.pagesRead }
            return (day: displayFmt.string(from: date), pages: pages)
        }
    }

    var weeklyPagesVsPreviousWeek: Double {
        let thisWeek = Double(pagesInWeek(offsetWeeks: 0))
        let lastWeek = Double(pagesInWeek(offsetWeeks: -1))
        guard lastWeek > 0 else { return 0 }
        return (thisWeek - lastWeek) / lastWeek * 100
    }

    // MARK: - Monthly Books Finished

    var monthlyBooksFinished: [(month: String, count: Int)] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let monthFmt = DateFormatter()
        monthFmt.dateFormat = "MMM"
        return (0..<6).reversed().map { offset in
            let monthDate = calendar.date(byAdding: .month, value: -offset, to: Date())!
            let mc = calendar.dateComponents([.year, .month], from: monthDate)
            let finished = entries.filter { entry in
                guard entry.status == .finished, !entry.bookTitle.isEmpty,
                      let d = df.date(from: entry.dateOnly) else { return false }
                let ec = calendar.dateComponents([.year, .month], from: d)
                return ec.year == mc.year && ec.month == mc.month
            }
            return (month: monthFmt.string(from: monthDate), count: Set(finished.map { $0.bookTitle }).count)
        }
    }

    // MARK: - Averages

    var averageReadingSpeed: Double {
        let sessions = entries.filter { $0.pagesRead > 0 && $0.minutesRead > 0 }
        guard !sessions.isEmpty else { return 0 }
        let totalPages = Double(sessions.reduce(0) { $0 + $1.pagesRead })
        let totalMinutes = Double(sessions.reduce(0) { $0 + $1.minutesRead })
        return totalPages / (totalMinutes / 60.0)
    }

    var averageRating: Double {
        let rated = entries.filter { $0.status == .finished && $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0.0) { $0 + $1.rating } / Double(rated.count)
    }

    var averageSessionDuration: Int {
        let sessions = entries.filter { $0.minutesRead > 0 }
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.minutesRead } / sessions.count
    }

    // MARK: - Genre Distribution

    var genreDistribution: [(genre: BookGenre, count: Int)] {
        // For each unique title, assign genre from its most recent entry
        var latestByTitle: [String: ReadingTrackerEntry] = [:]
        for entry in entries where !entry.bookTitle.isEmpty {
            if let existing = latestByTitle[entry.bookTitle] {
                if entry.date > existing.date { latestByTitle[entry.bookTitle] = entry }
            } else {
                latestByTitle[entry.bookTitle] = entry
            }
        }
        var genreCounts: [BookGenre: Int] = [:]
        for entry in latestByTitle.values {
            genreCounts[entry.genre, default: 0] += 1
        }
        return genreCounts.map { (genre: $0.key, count: $0.value) }.sorted { $0.count > $1.count }
    }

    // MARK: - Goal Progress

    var yearlyBookGoalProgress: Double {
        let goal = ReadingTrackerConstants.annualBookGoal
        guard goal > 0 else { return 0 }
        return Double(booksFinishedThisYear) / Double(goal)
    }

    // MARK: - Chart Data

    var weeklyTrendChartData: [ChartDataPoint] {
        weeklyReadingTrend.map { ChartDataPoint(label: $0.day, value: Double($0.pages)) }
    }

    var monthlyBooksChartData: [ChartDataPoint] {
        monthlyBooksFinished.map { ChartDataPoint(label: $0.month, value: Double($0.count)) }
    }

    var genreChartData: [ChartDataPoint] {
        genreDistribution.map { ChartDataPoint(label: $0.genre.displayName, value: Double($0.count)) }
    }

    // MARK: - Insights

    var insights: [String] {
        var result: [String] = []
        let streak = currentStreak

        // Streak alerts
        if streak >= 7 && streak == longestStreak {
            result.append("You've read \(streak) days in a row — your longest streak!")
        } else if streak >= 3 {
            result.append("You're on a \(streak)-day reading streak — keep it up!")
        } else if streak == 0 {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            let calendar = Calendar.current
            var gap = 0
            var check = calendar.date(byAdding: .day, value: -1, to: Date())!
            let activeDays = Set(entries.filter { $0.pagesRead > 0 }.map { $0.dateOnly })
            while gap < 30 {
                if activeDays.contains(df.string(from: check)) { break }
                gap += 1
                check = calendar.date(byAdding: .day, value: -1, to: check)!
            }
            if gap >= 3 {
                result.append("You haven't logged a session in \(gap) days — pick up where you left off?")
            }
        }

        // Pace comparison
        let change = weeklyPagesVsPreviousWeek
        if abs(change) >= 10 {
            let pct = Int(abs(change))
            result.append("You read \(pct)% \(change > 0 ? "more" : "fewer") pages this week than last week.")
        }

        // Annual goal projection
        let calendar = Calendar.current
        if let dayOfYear = calendar.ordinality(of: .day, in: .year, for: Date()),
           let daysInYear = calendar.range(of: .day, in: .year, for: Date())?.count,
           dayOfYear > 7 {
            let projected = Int(Double(booksFinishedThisYear) / Double(dayOfYear) * Double(daysInYear))
            let goal = ReadingTrackerConstants.annualBookGoal
            result.append("At your current pace, you'll finish \(projected) books this year (goal: \(goal)).")
        }

        // Reading speed
        let speed = averageReadingSpeed
        if speed > 0 {
            result.append(String(format: "Your average reading speed is %.0f pages/hour.", speed))
        }

        // Book completion nudge
        for book in currentlyReadingBooks where book.progressPercent >= 0.75 {
            let pct = Int(book.progressPercent * 100)
            result.append("You're \(pct)% through \"\(book.title)\" — almost there!")
        }

        // Top genre
        if let top = genreDistribution.first, top.count > 0 {
            result.append("\(top.genre.displayName) is your most-read genre with \(top.count) book\(top.count == 1 ? "" : "s").")
        }

        // Daily page goal
        let pagesDay = totalPagesReadToday
        let dailyGoal = ReadingTrackerConstants.dailyPageGoal
        if pagesDay >= dailyGoal {
            result.append("Daily goal reached: \(pagesDay)/\(dailyGoal) pages read today.")
        } else if pagesDay > 0 {
            result.append("\(pagesDay)/\(dailyGoal) pages read today — \(dailyGoal - pagesDay) more to go.")
        }

        return result
    }

    // MARK: - Module Insights (structured)

    var moduleInsights: [ModuleInsight] {
        var result: [ModuleInsight] = []
        let streak = currentStreak
        if streak >= 7 {
            result.append(ModuleInsight(type: .achievement, title: "\(streak)-Day Streak!",
                                        message: "You've read \(streak) days in a row — your longest streak!"))
        } else if streak >= 3 {
            result.append(ModuleInsight(type: .achievement, title: "\(streak)-Day Streak",
                                        message: "Keep the momentum going!"))
        }
        let change = weeklyPagesVsPreviousWeek
        if abs(change) >= 10 {
            let pct = Int(abs(change))
            result.append(ModuleInsight(type: .trend,
                                        title: change > 0 ? "Reading Up \(pct)%" : "Reading Down \(pct)%",
                                        message: "Pages read \(change > 0 ? "increased" : "decreased") vs last week."))
        }
        let goal = ReadingTrackerConstants.annualBookGoal
        let progress = Int(yearlyBookGoalProgress * 100)
        if progress >= 100 {
            result.append(ModuleInsight(type: .achievement, title: "Annual Goal Reached!",
                                        message: "You've finished \(booksFinishedThisYear) of \(goal) books this year."))
        } else {
            result.append(ModuleInsight(type: .trend, title: "Yearly Progress: \(progress)%",
                                        message: "\(booksFinishedThisYear) of \(goal) books finished this year."))
        }
        if todayEntries.isEmpty {
            result.append(ModuleInsight(type: .suggestion, title: "No session today",
                                        message: "Log a reading session to keep your streak alive."))
        }
        return result
    }

    // MARK: - CRUD

    func loadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data")!
            let (data, _) = try await URLSession.shared.data(from: url)
            entries = try JSONDecoder().decode([ReadingTrackerEntry].self, from: data)
            UserDefaults.standard.set(data, forKey: "dynamic_module_readingTracker_cache")
        } catch {
            entries = []
        }
    }

    func addEntry(_ entry: ReadingTrackerEntry) async {
        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data/add")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(entry)
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to add entry"
        }
    }

    func deleteEntry(_ entry: ReadingTrackerEntry) async {
        do {
            let url = URL(string: "\(bridgeBaseURL)/modules/readingTracker/data?id=\(entry.id)")!
            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            _ = try await URLSession.shared.data(for: request)
            await loadData()
        } catch {
            errorMessage = "Failed to delete entry"
        }
    }
}