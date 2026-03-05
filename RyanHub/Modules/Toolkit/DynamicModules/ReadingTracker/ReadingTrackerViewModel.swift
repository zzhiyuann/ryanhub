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

    // MARK: - Computed Properties

    var todayEntries: [ReadingTrackerEntry] {
        let today = DateFormatter()
        today.dateFormat = "yyyy-MM-dd"
        let todayStr = today.string(from: Date())
        return entries.filter { $0.date.hasPrefix(todayStr) }
    }

    var currentStreak: Int {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let entryDates = Set(entries.compactMap { df.date(from: String($0.date.prefix(10))) }.map { calendar.startOfDay(for: $0) })
        var streak = 0
        var day = calendar.startOfDay(for: Date())
        while entryDates.contains(day) {
            streak += 1
            day = calendar.date(byAdding: .day, value: -1, to: day)!
        }
        return streak
    }

    var longestStreak: Int {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let sortedDates = entries.compactMap { df.date(from: String($0.date.prefix(10))) }
            .map { calendar.startOfDay(for: $0) }
        let unique = Array(Set(sortedDates)).sorted()
        guard !unique.isEmpty else { return 0 }
        var longest = 1, current = 1
        for i in 1..<unique.count {
            if calendar.dateComponents([.day], from: unique[i-1], to: unique[i]).day == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    var weeklyChartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let displayFmt = DateFormatter()
        displayFmt.dateFormat = "E"
        var result: [ChartDataPoint] = []
        for dayOffset in (0..<7).reversed() {
            let day = calendar.date(byAdding: .day, value: -dayOffset, to: Date())!
            let dayStr = df.string(from: day)
            let count = entries.filter { $0.date.hasPrefix(dayStr) }.count
            result.append(ChartDataPoint(label: displayFmt.string(from: day), value: Double(count)))
        }
        return result
    }

    var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []
        if currentStreak >= 3 {
            result.append(ModuleInsight(type: .achievement, title: "\(currentStreak)-Day Streak!", message: "You've been consistent for \(currentStreak) days. Keep it up!"))
        }
        if todayEntries.isEmpty {
            result.append(ModuleInsight(type: .suggestion, title: "No entries today", message: "Don't forget to log your data for today."))
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
