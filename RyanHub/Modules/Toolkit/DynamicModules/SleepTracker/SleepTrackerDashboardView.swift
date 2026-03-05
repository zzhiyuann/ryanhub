import SwiftUI

struct SleepTrackerDashboardView: View {
    let viewModel: SleepTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                lastNightCard
                statGridSection
                streakSection
                recentEntriesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Last Night Card

    private var lastNightCard: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Night")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text(viewModel.lastNightEntry?.timeRangeLabel ?? "No sleep logged yet")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    Spacer()
                    if let mood = viewModel.lastNightEntry?.wakeUpMood {
                        HStack(spacing: 6) {
                            Image(systemName: mood.icon)
                                .font(.title3)
                                .foregroundStyle(moodColor(for: mood))
                            Text(mood.displayName)
                                .font(.hubCaption)
                                .foregroundStyle(moodColor(for: mood))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(moodColor(for: mood).opacity(0.12))
                        .clipShape(Capsule())
                    }
                }

                HStack(alignment: .center, spacing: HubLayout.sectionSpacing) {
                    ProgressRingView(
                        progress: viewModel.lastNightGoalProgress,
                        current: viewModel.lastNightEntry?.formattedDuration ?? "—",
                        unit: "",
                        goal: "of \(Int(SleepTrackerConstants.defaultDailyGoal))h goal",
                        color: ringColor,
                        size: 128,
                        lineWidth: 12
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        sleepMetricRow(
                            icon: "moon.fill",
                            label: "Bedtime",
                            value: viewModel.lastNightEntry?.formattedBedtime ?? "—",
                            color: Color.hubPrimary
                        )
                        sleepMetricRow(
                            icon: "sun.max.fill",
                            label: "Wake Time",
                            value: viewModel.lastNightEntry?.formattedWakeTime ?? "—",
                            color: Color.hubAccentYellow
                        )
                        sleepMetricRow(
                            icon: "star.fill",
                            label: "Quality",
                            value: viewModel.lastNightEntry?.qualityStars ?? "—",
                            color: Color.hubAccentGreen
                        )
                        if let disruptor = viewModel.lastNightEntry?.sleepDisruptor, disruptor.isActive {
                            sleepMetricRow(
                                icon: disruptor.icon,
                                label: "Disruptor",
                                value: disruptor.displayName,
                                color: Color.hubAccentRed
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private func sleepMetricRow(icon: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Stat Grid

    private var statGridSection: some View {
        StatGrid {
            StatCard(
                title: "7-Day Avg",
                value: viewModel.weeklyAverageDurationFormatted,
                icon: "clock.fill",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Avg Quality",
                value: String(format: "%.1f / 5", viewModel.weeklyAverageQuality),
                icon: "star.fill",
                color: Color.hubAccentYellow
            )
            StatCard(
                title: "Total Nights",
                value: "\(viewModel.totalEntries)",
                icon: "moon.zzz.fill",
                color: Color.hubAccentGreen
            )
            StatCard(
                title: "Best Sleep",
                value: viewModel.bestSleepEntry?.formattedDuration ?? "—",
                icon: "crown.fill",
                color: Color.hubAccentRed
            )
        }
    }

    // MARK: - Streak Section

    private var streakSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Goal Streak")
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    unit: "nights",
                    isActiveToday: viewModel.isActiveToday
                )
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Recent Entries

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Sleep Log")

            if viewModel.recentEntries.isEmpty {
                HubCard {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.hubPrimary.opacity(0.4))
                        Text("No sleep logged yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Tap + to record your first night")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(HubLayout.sectionSpacing)
                }
            } else {
                ForEach(viewModel.recentEntries) { entry in
                    HubCard {
                        HStack(spacing: HubLayout.itemSpacing) {
                            ZStack {
                                Circle()
                                    .fill(qualityColor(for: entry.qualityRating).opacity(0.15))
                                    .frame(width: 46, height: 46)
                                Image(systemName: entry.wakeUpMood.icon)
                                    .font(.headline)
                                    .foregroundStyle(qualityColor(for: entry.qualityRating))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.summaryLine)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .lineLimit(1)
                                HStack(spacing: 6) {
                                    Text(entry.formattedDate)
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    if entry.sleepDisruptor.isActive {
                                        Text("·")
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        Image(systemName: entry.sleepDisruptor.icon)
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                                        Text(entry.sleepDisruptor.displayName)
                                            .font(.hubCaption)
                                            .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                                    }
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "moon.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.hubPrimary.opacity(0.7))
                                    Text(entry.timeRangeLabel)
                                        .font(.hubCaption)
                                        .foregroundStyle(Color.hubPrimary.opacity(0.8))
                                    if entry.dreamRecall {
                                        Text("·")
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        Image(systemName: "cloud.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.hubPrimary.opacity(0.5))
                                        Text("Dream")
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }
                                }
                            }

                            Spacer()

                            Button {
                                Task { await viewModel.deleteEntry(entry) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(Color.hubAccentRed.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(HubLayout.standardPadding)
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private var ringColor: Color {
        guard let entry = viewModel.lastNightEntry else { return Color.hubPrimary }
        return qualityColor(for: entry.qualityRating)
    }

    private func qualityColor(for rating: Int) -> Color {
        switch rating {
        case 4...5: return Color.hubAccentGreen
        case 3:     return Color.hubAccentYellow
        default:    return Color.hubAccentRed
        }
    }

    private func moodColor(for mood: WakeUpMood) -> Color {
        switch mood {
        case .energized, .rested: return Color.hubAccentGreen
        case .neutral:            return Color.hubAccentYellow
        case .groggy, .exhausted: return Color.hubAccentRed
        }
    }
}