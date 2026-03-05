import SwiftUI

struct HydrationTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HydrationTrackerViewModel

    private var todayProgress: Double {
        guard viewModel.dailyGoalOz > 0 else { return 0 }
        return min(1.0, viewModel.todayTotalEffectiveOz / viewModel.dailyGoalOz)
    }

    private var progressColor: Color {
        switch todayProgress {
        case 0..<0.4: return Color.hubAccentRed
        case 0.4..<0.75: return Color.hubAccentYellow
        default: return Color.hubAccentGreen
        }
    }

    private var remainingOz: Double {
        max(0, viewModel.dailyGoalOz - viewModel.todayTotalEffectiveOz)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                todayProgressSection
                statsSection
                streakSection
                beverageBreakdownSection
                recentEntriesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Today Progress

    private var todayProgressSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack(alignment: .top, spacing: HubLayout.standardPadding) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Today's Hydration")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        if viewModel.isGoalMetToday {
                            Label("Goal Reached!", systemImage: "checkmark.seal.fill")
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentGreen)
                        } else {
                            Text(String(format: "%.0f oz remaining", remainingOz))
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        Spacer()

                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.0f entries", Double(viewModel.todayEntries.count)))
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                            if let last = viewModel.todayEntries.last {
                                Label(last.formattedTime, systemImage: "clock")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }

                    Spacer()

                    ProgressRingView(
                        progress: todayProgress,
                        current: String(format: "%.0f", viewModel.todayTotalEffectiveOz),
                        unit: "oz",
                        goal: String(format: "of %.0f", viewModel.dailyGoalOz),
                        color: progressColor,
                        size: 130,
                        lineWidth: 13
                    )
                }

                intakeTimelineBar
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private var intakeTimelineBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Intake Timeline")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(AdaptiveColors.background(for: colorScheme))
                        .frame(height: 10)

                    // Per-entry ticks
                    ForEach(viewModel.todayEntries) { entry in
                        let fraction = Double(entry.hour) / 24.0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.hubPrimary.opacity(0.7))
                            .frame(width: max(4, (entry.effectiveOz / max(1, viewModel.dailyGoalOz)) * geo.size.width * 0.6), height: 10)
                            .offset(x: fraction * geo.size.width)
                    }

                    // Progress fill
                    RoundedRectangle(cornerRadius: 5)
                        .fill(
                            LinearGradient(
                                colors: [progressColor.opacity(0.4), progressColor.opacity(0.15)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * todayProgress, height: 10)
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: todayProgress)
                }
            }
            .frame(height: 10)

            HStack {
                Text("12am")
                Spacer()
                Text("6am")
                Spacer()
                Text("Noon")
                Spacer()
                Text("6pm")
                Spacer()
                Text("Now")
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.55))
        }
    }

    // MARK: - Stats Grid

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Overview")

            StatGrid {
                StatCard(
                    title: "Today's Total",
                    value: String(format: "%.0f oz", viewModel.todayTotalEffectiveOz),
                    icon: "drop.fill",
                    color: progressColor
                )
                StatCard(
                    title: "Daily Goal",
                    value: String(format: "%.0f oz", viewModel.dailyGoalOz),
                    icon: "target",
                    color: Color.hubPrimary
                )
                StatCard(
                    title: "7-Day Avg",
                    value: String(format: "%.0f oz", viewModel.weeklyAverageOz),
                    icon: "chart.line.uptrend.xyaxis",
                    color: Color.hubAccentGreen
                )
                StatCard(
                    title: "Entries Today",
                    value: "\(viewModel.todayEntries.count)",
                    icon: "list.bullet.clipboard.fill",
                    color: Color.hubAccentYellow
                )
            }
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Consistency")

            HubCard {
                StreakCounter(
                    currentStreak: viewModel.currentStreak,
                    longestStreak: viewModel.longestStreak,
                    unit: "days",
                    isActiveToday: viewModel.isGoalMetToday
                )
                .padding(HubLayout.standardPadding)
            }
        }
    }

    // MARK: - Beverage Breakdown

    private var beverageBreakdownSection: some View {
        let grouped = Dictionary(grouping: viewModel.todayEntries, by: { $0.beverageType })
        guard !grouped.isEmpty else { return AnyView(EmptyView()) }

        let total = viewModel.todayEntries.reduce(0) { $0 + $1.effectiveOz }
        let sorted = grouped.sorted { a, b in
            a.value.reduce(0) { $0 + $1.effectiveOz } > b.value.reduce(0) { $0 + $1.effectiveOz }
        }

        return AnyView(
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Beverage Mix")

                HubCard {
                    VStack(spacing: 10) {
                        ForEach(sorted, id: \.key) { type, entries in
                            let oz = entries.reduce(0) { $0 + $1.effectiveOz }
                            let fraction = total > 0 ? oz / total : 0

                            HStack(spacing: 10) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.hubPrimary)
                                    .frame(width: 20)

                                Text(type.displayName)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                                Spacer()

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.hubPrimary.opacity(0.12))
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(Color.hubPrimary.opacity(0.65))
                                            .frame(width: geo.size.width * fraction)
                                    }
                                }
                                .frame(width: 80, height: 6)

                                Text(String(format: "%.0f oz", oz))
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    .frame(width: 48, alignment: .trailing)
                            }
                        }
                    }
                    .padding(HubLayout.standardPadding)
                }
            }
        )
    }

    // MARK: - Recent Entries

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Entries")

            if viewModel.todayEntries.isEmpty {
                HubCard {
                    VStack(spacing: 12) {
                        Image(systemName: "drop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.hubPrimary.opacity(0.4))

                        Text("No drinks logged yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Text("Tap + to record your first drink today")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                }
            } else {
                VStack(spacing: HubLayout.itemSpacing) {
                    ForEach(viewModel.todayEntries.reversed()) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    private func entryRow(_ entry: HydrationTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: entry.beverageType.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.beverageType.displayName)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text(entry.summaryLine)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Label(entry.formattedTime, systemImage: "clock")
                            .font(.system(size: 11))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))

                        if entry.beverageType.hydrationCoefficient < 1.0 {
                            Text("·")
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                            Text(entry.beverageType.coefficientLabel)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.hubAccentYellow)
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    Text(entry.formattedEffectiveOz)
                        .font(.hubCaption.weight(.semibold))
                        .foregroundStyle(Color.hubPrimary)

                    Button {
                        Task { await viewModel.deleteEntry(entry) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.hubAccentRed.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }
}