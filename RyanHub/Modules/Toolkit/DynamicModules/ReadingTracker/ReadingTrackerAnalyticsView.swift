import SwiftUI

struct ReadingTrackerAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ReadingTrackerViewModel

    // MARK: - Computed Stats

    private var entries: [ReadingTrackerEntry] { viewModel.entries }

    private var totalPagesRead: Int {
        entries.reduce(0) { $0 + $1.pagesRead }
    }

    private var totalReadingMinutes: Int {
        entries.reduce(0) { $0 + $1.readingMinutes }
    }

    private var totalReadingHours: Double {
        Double(totalReadingMinutes) / 60.0
    }

    private var totalBooksCompleted: Int {
        Set(entries.filter { $0.status == .completed }.map { $0.bookTitle }).count
    }

    private var averageRating: Double {
        let rated = entries.filter { $0.hasRating }
        guard !rated.isEmpty else { return 0 }
        return rated.reduce(0.0) { $0 + $1.rating } / Double(rated.count)
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(entries.compactMap { entry -> Date? in
            guard let d = entry.parsedDate else { return nil }
            return calendar.startOfDay(for: d)
        })
        var streak = 0
        var date = calendar.startOfDay(for: Date())
        while activeDays.contains(date) {
            streak += 1
            guard let prev = calendar.date(byAdding: .day, value: -1, to: date) else { break }
            date = prev
        }
        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let activeDays = Set(entries.compactMap { entry -> Date? in
            guard let d = entry.parsedDate else { return nil }
            return calendar.startOfDay(for: d)
        }).sorted()
        guard !activeDays.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        for i in 1..<activeDays.count {
            let diff = calendar.dateComponents([.day], from: activeDays[i - 1], to: activeDays[i]).day ?? 0
            if diff == 1 {
                current += 1
                if current > longest { longest = current }
            } else {
                current = 1
            }
        }
        return longest
    }

    private var isActiveToday: Bool {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let today = f.string(from: Date())
        return entries.contains { $0.dateOnly == today }
    }

    private var yearlyGoalProgress: Double {
        min(1.0, Double(totalBooksCompleted) / Double(ReadingTrackerConstants.defaultYearlyBookGoal))
    }

    private var weeklyChartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let today = Date()
        let dayFmt = DateFormatter()
        dayFmt.dateFormat = "yyyy-MM-dd"
        let labelFmt = DateFormatter()
        labelFmt.dateFormat = "EEE"
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let key = dayFmt.string(from: date)
            let pages = entries.filter { $0.dateOnly == key }.reduce(0) { $0 + $1.pagesRead }
            return ChartDataPoint(label: labelFmt.string(from: date), value: Double(pages))
        }
    }

    private var activityData: [Date: Double] {
        let calendar = Calendar.current
        var dict: [Date: Double] = [:]
        for entry in entries {
            guard let date = entry.parsedDate else { continue }
            let day = calendar.startOfDay(for: date)
            let value = entry.pagesRead > 0 ? Double(entry.pagesRead) : (entry.readingMinutes > 0 ? 1.0 : 0.0)
            dict[day, default: 0] += value
        }
        return dict
    }

    private var topGenres: [(BookGenre, Int)] {
        var counts: [BookGenre: Int] = [:]
        for entry in entries { counts[entry.genre, default: 0] += 1 }
        return counts.sorted { $0.value > $1.value }.prefix(5).map { ($0.key, $0.value) }
    }

    private var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []
        if currentStreak >= 7 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "\(currentStreak)-Day Reading Streak",
                message: "You've read every day for \(currentStreak) days straight. Consistency builds a reading habit!"
            ))
        }
        let booksRemaining = ReadingTrackerConstants.defaultYearlyBookGoal - totalBooksCompleted
        if booksRemaining <= 0 {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Yearly Goal Achieved",
                message: "You've completed all \(ReadingTrackerConstants.defaultYearlyBookGoal) books on your yearly reading goal!"
            ))
        } else {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Yearly Goal",
                message: "\(booksRemaining) books remaining to hit your goal of \(ReadingTrackerConstants.defaultYearlyBookGoal) this year."
            ))
        }
        if totalPagesRead >= 5000 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Pages Milestone",
                message: "You've read \(totalPagesRead) pages total — that's roughly \(totalPagesRead / 300)+ full novels worth!"
            ))
        }
        if averageRating >= 4.0 {
            result.append(ModuleInsight(
                type: .trend,
                title: "Excellent Taste",
                message: String(format: "Your average book rating is %.1f★ — you're picking great books!", averageRating)
            ))
        } else if averageRating > 0 && averageRating < 3.0 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Explore New Genres",
                message: "Your ratings average \(String(format: "%.1f", averageRating))★ — try a different genre to find your next favorite."
            ))
        }
        return result
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Streak + Yearly Goal
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        StreakCounter(
                            currentStreak: currentStreak,
                            longestStreak: longestStreak,
                            unit: "days",
                            isActiveToday: isActiveToday
                        )
                        Divider()
                            .padding(.vertical, 4)
                        HStack(spacing: HubLayout.standardPadding) {
                            ProgressRingView(
                                progress: yearlyGoalProgress,
                                current: "\(totalBooksCompleted)",
                                unit: "books",
                                goal: "of \(ReadingTrackerConstants.defaultYearlyBookGoal) yearly",
                                color: Color.hubPrimary,
                                size: 96,
                                lineWidth: 9
                            )
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Yearly Reading Goal")
                                    .font(.hubHeading)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("\(totalBooksCompleted) of \(ReadingTrackerConstants.defaultYearlyBookGoal) books completed")
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                let remaining = max(0, ReadingTrackerConstants.defaultYearlyBookGoal - totalBooksCompleted)
                                if remaining > 0 {
                                    Text("\(remaining) to go")
                                        .font(.hubCaption)
                                        .foregroundStyle(Color.hubAccentYellow)
                                } else {
                                    Text("Goal achieved!")
                                        .font(.hubCaption)
                                        .foregroundStyle(Color.hubAccentGreen)
                                }
                            }
                            Spacer()
                        }
                    }
                    .padding(HubLayout.standardPadding)
                }

                // Summary Stats
                StatGrid {
                    StatCard(
                        title: "Pages Read",
                        value: totalPagesRead > 0 ? "\(totalPagesRead)" : "—",
                        icon: "book.pages.fill",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Reading Time",
                        value: totalReadingHours >= 1 ? String(format: "%.1fh", totalReadingHours) : "\(totalReadingMinutes)m",
                        icon: "clock.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Books Done",
                        value: "\(totalBooksCompleted)",
                        icon: "checkmark.circle.fill",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "Avg Rating",
                        value: averageRating > 0 ? String(format: "%.1f★", averageRating) : "—",
                        icon: "star.fill",
                        color: Color.hubAccentRed
                    )
                }

                // Weekly Pages Chart
                ModuleChartView(
                    title: "Pages Read — Last 7 Days",
                    subtitle: "Daily page count",
                    dataPoints: weeklyChartData,
                    style: .bar,
                    color: Color.hubPrimary,
                    showArea: false
                )

                // Activity Heatmap
                CalendarHeatmap(
                    title: "Reading Activity",
                    data: activityData,
                    color: Color.hubPrimary,
                    weeks: 12
                )

                // Genre Breakdown
                if !topGenres.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Top Genres")
                            let maxCount = topGenres.first?.1 ?? 1
                            ForEach(topGenres, id: \.0.id) { genre, count in
                                VStack(spacing: 6) {
                                    HStack {
                                        Image(systemName: genre.icon)
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hubPrimary)
                                            .frame(width: 20)
                                        Text(genre.displayName)
                                            .font(.hubBody)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Spacer()
                                        Text("\(count) session\(count == 1 ? "" : "s")")
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.hubPrimary.opacity(0.12))
                                                .frame(height: 5)
                                            RoundedRectangle(cornerRadius: 3)
                                                .fill(Color.hubPrimary)
                                                .frame(width: geo.size.width * (Double(count) / Double(maxCount)), height: 5)
                                        }
                                    }
                                    .frame(height: 5)
                                }
                            }
                        }
                        .padding(HubLayout.standardPadding)
                    }
                }

                // Insights
                if !insights.isEmpty {
                    InsightsList(insights: insights)
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}