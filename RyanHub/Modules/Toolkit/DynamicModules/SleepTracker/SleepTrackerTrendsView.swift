import SwiftUI

struct SleepTrackerTrendsView: View {
    let viewModel: SleepTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                sleepDebtSection
                consistencySection
                durationTrendSection
                moodBreakdownSection
                insightsSection
                streakSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Sleep Debt Gauge

    private var sleepDebtSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Sleep Debt (14 Days)")

                HStack(spacing: 8) {
                    Text(String(format: "%.1fh", viewModel.sleepDebt))
                        .font(.hubHeading)
                        .foregroundStyle(debtColor)

                    Text(viewModel.sleepDebtLevel.label)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))

                        RoundedRectangle(cornerRadius: 6)
                            .fill(debtColor)
                            .frame(width: max(0, geo.size.width * debtProgress))
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("0h")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Spacer()
                    Text("14h+")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Consistency Score

    private var consistencySection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Bedtime Consistency")

                ProgressRingView(
                    progress: Double(viewModel.consistencyScore) / 100.0,
                    current: "\(viewModel.consistencyScore)",
                    unit: "",
                    goal: nil,
                    color: consistencyColor,
                    size: 100,
                    lineWidth: 8
                )

                Text(viewModel.consistencyGrade.label)
                    .font(.hubBody)
                    .foregroundStyle(consistencyColor)

                Text("Based on 30-day bedtime variation")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - 30-Day Duration Trend

    private var durationTrendSection: some View {
        ModuleChartView(
            title: "30-Day Duration",
            subtitle: "Target: \(String(format: "%.0f", viewModel.sleepGoal))h",
            dataPoints: viewModel.thirtyDayDurationChartData,
            style: .line,
            color: Color.hubPrimary,
            showArea: true
        )
    }

    // MARK: - Mood Breakdown

    private var moodBreakdownSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Wake Mood (30 Days)")

                let distribution = viewModel.moodDistribution
                let total = distribution.values.reduce(0, +)

                if total > 0 {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(sortedMoods, id: \.self) { mood in
                                let count = distribution[mood] ?? 0
                                if count > 0 {
                                    let fraction = CGFloat(count) / CGFloat(total)
                                    RoundedRectangle(cornerRadius: 0)
                                        .fill(moodColor(mood))
                                        .frame(width: geo.size.width * fraction)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .frame(height: 24)

                    // Legend
                    FlowLegend(distribution: distribution, total: total, colorScheme: colorScheme)
                } else {
                    Text("No mood data yet")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        Group {
            if !viewModel.insights.isEmpty {
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: "Insights")
                    InsightsList(insights: viewModel.insights)
                }
            }
        }
    }

    // MARK: - Streak Counter

    private var streakSection: some View {
        StreakCounter(
            currentStreak: viewModel.currentStreak,
            longestStreak: longestStreak,
            unit: "days",
            isActiveToday: viewModel.todayEntry != nil
        )
    }

    // MARK: - Helpers

    private var debtProgress: Double {
        min(1.0, viewModel.sleepDebt / 14.0)
    }

    private var debtColor: Color {
        switch viewModel.sleepDebtLevel {
        case .healthy: return Color.hubAccentGreen
        case .mild: return Color.hubAccentYellow
        case .moderate: return Color.hubPrimaryLight
        case .severe: return Color.hubAccentRed
        }
    }

    private var consistencyColor: Color {
        switch viewModel.consistencyGrade {
        case .excellent: return Color.hubAccentGreen
        case .good: return Color.hubPrimaryLight
        case .fair: return Color.hubAccentYellow
        case .poor: return Color.hubAccentRed
        }
    }

    private var sortedMoods: [WakeMood] {
        WakeMood.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func moodColor(_ mood: WakeMood) -> Color {
        switch mood {
        case .energized: return Color.hubAccentYellow
        case .refreshed: return Color.hubAccentGreen
        case .neutral: return Color.gray
        case .groggy: return Color.hubPrimary
        case .exhausted: return Color.hubAccentRed
        }
    }

    private var longestStreak: Int {
        let cal = Calendar.current
        let sortedDates = viewModel.entries
            .compactMap { $0.calendarDate }
            .map { cal.startOfDay(for: $0) }
            .sorted()

        guard !sortedDates.isEmpty else { return 0 }

        var uniqueDates: [Date] = [sortedDates[0]]
        for date in sortedDates.dropFirst() {
            if !cal.isDate(date, inSameDayAs: uniqueDates.last!) {
                uniqueDates.append(date)
            }
        }

        var longest = 1
        var current = 1

        for i in 1..<uniqueDates.count {
            if let next = cal.date(byAdding: .day, value: 1, to: uniqueDates[i - 1]),
               cal.isDate(next, inSameDayAs: uniqueDates[i]) {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }

        return longest
    }
}

// MARK: - Flow Legend

private struct FlowLegend: View {
    let distribution: [WakeMood: Int]
    let total: Int
    let colorScheme: ColorScheme

    private var sortedMoods: [WakeMood] {
        WakeMood.allCases.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            ForEach(sortedMoods, id: \.self) { mood in
                let count = distribution[mood] ?? 0
                if count > 0 {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(colorFor(mood))
                            .frame(width: 8, height: 8)
                        Text("\(mood.displayName) \(Int(Double(count) / Double(total) * 100))%")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
            }
        }
    }

    private func colorFor(_ mood: WakeMood) -> Color {
        switch mood {
        case .energized: return Color.hubAccentYellow
        case .refreshed: return Color.hubAccentGreen
        case .neutral: return Color.gray
        case .groggy: return Color.hubPrimary
        case .exhausted: return Color.hubAccentRed
        }
    }
}