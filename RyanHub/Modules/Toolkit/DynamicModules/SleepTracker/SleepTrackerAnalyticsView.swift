import SwiftUI

@MainActor
struct SleepTrackerAnalyticsView: View {
    let viewModel: SleepTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Stats

    private var entries: [SleepTrackerEntry] { viewModel.entries }

    private var averageDuration: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.durationHours).reduce(0, +) / Double(entries.count)
    }

    private var averageQuality: Double {
        guard !entries.isEmpty else { return 0 }
        return entries.map { Double($0.qualityRating) }.reduce(0, +) / Double(entries.count)
    }

    private var goalHitRate: Double {
        guard !entries.isEmpty else { return 0 }
        let hits = entries.filter(\.meetsGoal).count
        return Double(hits) / Double(entries.count)
    }

    private var optimalNights: Int {
        entries.filter {
            $0.durationHours >= SleepTrackerConstants.optimalMinHours &&
            $0.durationHours <= SleepTrackerConstants.optimalMaxHours
        }.count
    }

    private var dreamRecallCount: Int {
        entries.filter(\.dreamRecall).count
    }

    private var heatmapData: [Date: Double] {
        var data: [Date: Double] = [:]
        for entry in entries {
            if let date = entry.calendarDate {
                data[date] = entry.heatmapIntensity
            }
        }
        return data
    }

    private var moodCounts: [(WakeUpMood, Int)] {
        WakeUpMood.allCases.compactMap { mood in
            let count = entries.filter { $0.wakeUpMood == mood }.count
            return count > 0 ? (mood, count) : nil
        }
    }

    private var topDisruptors: [(SleepDisruptor, Int)] {
        let active = entries.filter { $0.sleepDisruptor.isActive }
        return SleepDisruptor.allCases
            .filter(\.isActive)
            .compactMap { d in
                let count = active.filter { $0.sleepDisruptor == d }.count
                return count > 0 ? (d, count) : nil
            }
            .sorted { $0.1 > $1.1 }
            .prefix(4)
            .map { $0 }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Duration chart
                ModuleChartView(
                    title: "Sleep Duration",
                    subtitle: "Last 7 nights (hours)",
                    dataPoints: viewModel.chartData,
                    style: .bar,
                    color: Color.hubPrimary,
                    showArea: false
                )

                // Key stats grid
                StatGrid {
                    StatCard(
                        title: "Avg Duration",
                        value: formatHours(averageDuration),
                        icon: "bed.double.fill",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Avg Quality",
                        value: String(format: "%.1f / 5", averageQuality),
                        icon: "star.fill",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "Goal Nights",
                        value: "\(Int(goalHitRate * 100))%",
                        icon: "target",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Optimal Range",
                        value: "\(optimalNights)",
                        icon: "moon.zzz.fill",
                        color: Color.hubAccentGreen
                    )
                }

                // Streak
                HubCard {
                    StreakCounter(
                        currentStreak: viewModel.currentStreak,
                        longestStreak: viewModel.longestStreak,
                        unit: "nights",
                        isActiveToday: viewModel.isActiveToday
                    )
                }

                // Sleep summary card
                HubCard {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Sleep Summary")

                        summaryRow(
                            icon: "moon.stars.fill",
                            label: "Total Nights Logged",
                            value: "\(entries.count)",
                            color: Color.hubPrimary
                        )
                        Divider().opacity(0.3)
                        summaryRow(
                            icon: "sparkles",
                            label: "Dream Recall Nights",
                            value: "\(dreamRecallCount)",
                            color: Color.hubAccentYellow
                        )
                        Divider().opacity(0.3)
                        summaryRow(
                            icon: "bed.double.fill",
                            label: "Sleep Goal",
                            value: "\(Int(SleepTrackerConstants.defaultDailyGoal))h / night",
                            color: Color.hubPrimary
                        )
                        Divider().opacity(0.3)
                        summaryRow(
                            icon: "clock.fill",
                            label: "Optimal Range",
                            value: "\(Int(SleepTrackerConstants.optimalMinHours))–\(Int(SleepTrackerConstants.optimalMaxHours))h",
                            color: Color.hubAccentGreen
                        )
                    }
                    .padding(HubLayout.standardPadding)
                }

                // Calendar heatmap
                CalendarHeatmap(
                    title: "Sleep Quality",
                    data: heatmapData,
                    color: Color.hubPrimary,
                    weeks: 12
                )

                // Wake-up mood breakdown
                if !moodCounts.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Wake-Up Mood")
                            ForEach(moodCounts, id: \.0.id) { mood, count in
                                HStack(spacing: 10) {
                                    Image(systemName: mood.icon)
                                        .foregroundStyle(moodColor(mood))
                                        .frame(width: 20)
                                    Text(mood.displayName)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    ZStack(alignment: .leading) {
                                        Capsule()
                                            .fill(Color.hubPrimary.opacity(0.12))
                                            .frame(width: 80, height: 6)
                                        let pct = entries.isEmpty ? 0 : CGFloat(count) / CGFloat(entries.count)
                                        Capsule()
                                            .fill(moodColor(mood))
                                            .frame(width: 80 * pct, height: 6)
                                    }
                                    Text("\(count)")
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        .frame(width: 24, alignment: .trailing)
                                }
                            }
                        }
                        .padding(HubLayout.standardPadding)
                    }
                }

                // Sleep disruptors
                if !topDisruptors.isEmpty {
                    HubCard {
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: "Sleep Disruptors")
                            ForEach(topDisruptors, id: \.0.id) { disruptor, count in
                                HStack(spacing: 10) {
                                    Image(systemName: disruptor.icon)
                                        .foregroundStyle(Color.hubAccentRed)
                                        .frame(width: 20)
                                    Text(disruptor.displayName)
                                        .font(.hubBody)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    Spacer()
                                    Text("\(count)×")
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                }
                            }
                        }
                        .padding(HubLayout.standardPadding)
                    }
                }

                // Insights
                InsightsList(insights: viewModel.moduleInsights)
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func summaryRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 22)
            Text(label)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.hubBody)
                .fontWeight(.semibold)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    private func formatHours(_ hours: Double) -> String {
        let h = Int(hours)
        let m = Int((hours - Double(h)) * 60)
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func moodColor(_ mood: WakeUpMood) -> Color {
        switch mood {
        case .energized: return Color.hubAccentGreen
        case .rested:    return Color.hubPrimary
        case .neutral:   return Color.hubAccentYellow
        case .groggy:    return Color.hubAccentYellow.opacity(0.7)
        case .exhausted: return Color.hubAccentRed
        }
    }
}