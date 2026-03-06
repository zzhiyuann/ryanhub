import SwiftUI

// MARK: - HabitTrackerStatsView

struct HabitTrackerStatsView: View {
    let viewModel: HabitTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var pulseAnimation = false

    private let calendar = Calendar.current
    private let dayLabels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                weeklyCompletionCard
                categoryBreakdownSection
                bestDaySection
                milestonesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseAnimation = true
            }
        }
    }

    // MARK: - Weekly Completion Rate

    private var weeklyCompletionCard: some View {
        let stats = weeklyCompletionStats
        return HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Text("Weekly Average")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(stats.thisWeekRate * 100))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("%")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    Spacer().frame(width: 8)

                    trendArrow(change: stats.thisWeekRate - stats.lastWeekRate)
                }

                Text("daily completion rate")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func trendArrow(change: Double) -> some View {
        let isUp = change >= 0
        let percentage = abs(Int(change * 100))
        return HStack(spacing: 2) {
            Image(systemName: isUp ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 14, weight: .bold))
            Text("\(percentage)%")
                .font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(isUp ? Color.hubAccentGreen : Color.hubAccentRed)
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "By Category")

            HubCard {
                VStack(spacing: 12) {
                    let rates = categoryCompletionRates
                    if rates.isEmpty {
                        Text("No category data yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(rates, id: \.category) { item in
                            categoryBar(item: item)
                        }
                    }
                }
            }
        }
    }

    private func categoryBar(item: CategoryRate) -> some View {
        HStack(spacing: HubLayout.itemSpacing) {
            HStack(spacing: 6) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(categoryColor(for: item.category))
                Text(item.category.displayName)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
            .frame(width: 110, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor(for: item.category).opacity(0.15))
                        .frame(height: 20)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(categoryColor(for: item.category))
                        .frame(width: max(geo.size.width * item.rate, 4), height: 20)
                }
            }
            .frame(height: 20)

            Text("\(Int(item.rate * 100))%")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .frame(width: 40, alignment: .trailing)
        }
    }

    // MARK: - Best Day of Week

    private var bestDaySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Best Day")

            HubCard {
                VStack(spacing: 12) {
                    let dayRates = dayOfWeekRates
                    let maxRate = dayRates.max() ?? 1.0
                    let bestIndex = dayRates.enumerated().max(by: { $0.element < $1.element })?.offset

                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { index in
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .stroke(
                                            Color.hubPrimary.opacity(0.2),
                                            lineWidth: 3
                                        )
                                        .frame(width: 36, height: 36)

                                    Circle()
                                        .trim(from: 0, to: maxRate > 0 ? dayRates[index] / maxRate : 0)
                                        .stroke(
                                            Color.hubPrimary,
                                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                                        )
                                        .frame(width: 36, height: 36)
                                        .rotationEffect(.degrees(-90))

                                    Text("\(Int(dayRates[index] * 100))")
                                        .font(.system(size: 9, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            index == bestIndex
                                                ? Color.hubPrimary
                                                : AdaptiveColors.textSecondary(for: colorScheme)
                                        )
                                }

                                Text(dayLabels[index])
                                    .font(.system(size: 12, weight: index == bestIndex ? .bold : .medium))
                                    .foregroundStyle(
                                        index == bestIndex
                                            ? Color.hubPrimary
                                            : AdaptiveColors.textSecondary(for: colorScheme)
                                    )
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Milestones

    private var milestonesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Milestones")

            let milestones = earnedMilestones
            if milestones.isEmpty {
                HubCard {
                    VStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                        Text("Keep building streaks to earn badges")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HubLayout.standardPadding)
                }
            } else {
                let columns = [
                    GridItem(.flexible(), spacing: HubLayout.itemSpacing),
                    GridItem(.flexible(), spacing: HubLayout.itemSpacing),
                    GridItem(.flexible(), spacing: HubLayout.itemSpacing)
                ]
                LazyVGrid(columns: columns, spacing: HubLayout.itemSpacing) {
                    ForEach(milestones) { milestone in
                        milestoneBadge(milestone: milestone)
                    }
                }
            }
        }
    }

    private func milestoneBadge(milestone: EarnedMilestone) -> some View {
        let color = tierColor(for: milestone.tier)
        let isRecent = milestone.isRecent

        return HubCard {
            VStack(spacing: 6) {
                ZStack {
                    if isRecent {
                        Circle()
                            .fill(color.opacity(pulseAnimation ? 0.3 : 0.1))
                            .frame(width: 52, height: 52)
                    }

                    Image(systemName: milestone.tier.icon)
                        .font(.system(size: 24))
                        .foregroundStyle(color)
                }
                .frame(height: 44)

                Text("\(milestone.tier.rawValue)d")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                Text(milestone.habitName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
        }
        .shadow(color: isRecent ? color.opacity(pulseAnimation ? 0.4 : 0.0) : .clear, radius: 8)
    }

    // MARK: - Data Computation

    private struct WeeklyStats {
        let thisWeekRate: Double
        let lastWeekRate: Double
    }

    private struct CategoryRate {
        let category: HabitCategory
        let rate: Double
    }

    private struct EarnedMilestone: Identifiable {
        let id: String
        let habitName: String
        let tier: MilestoneTier
        let isRecent: Bool
    }

    private var weeklyCompletionStats: WeeklyStats {
        let today = calendar.startOfDay(for: Date())
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        guard let weekStart = calendar.date(byAdding: .day, value: -(calendar.component(.weekday, from: today) - calendar.firstWeekday + 7) % 7, to: today),
              let lastWeekStart = calendar.date(byAdding: .day, value: -7, to: weekStart) else {
            return WeeklyStats(thisWeekRate: 0, lastWeekRate: 0)
        }

        let habits = uniqueHabits
        guard !habits.isEmpty else {
            return WeeklyStats(thisWeekRate: 0, lastWeekRate: 0)
        }

        let thisWeekDays = daysElapsedInRange(from: weekStart, to: today)
        let totalPossibleThisWeek = max(habits.count * max(thisWeekDays, 1), 1)
        let thisWeekCount = viewModel.entries.filter { entry in
            guard let d = df.date(from: String(entry.date.prefix(10))) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= weekStart && day <= today
        }.count
        let thisWeekRate = min(Double(thisWeekCount) / Double(totalPossibleThisWeek), 1.0)

        let totalPossibleLastWeek = max(habits.count * 7, 1)
        let lastWeekCount = viewModel.entries.filter { entry in
            guard let d = df.date(from: String(entry.date.prefix(10))) else { return false }
            let day = calendar.startOfDay(for: d)
            return day >= lastWeekStart && day < weekStart
        }.count
        let lastWeekRate = min(Double(lastWeekCount) / Double(totalPossibleLastWeek), 1.0)

        return WeeklyStats(thisWeekRate: thisWeekRate, lastWeekRate: lastWeekRate)
    }

    private var categoryCompletionRates: [CategoryRate] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        guard let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today) else { return [] }

        let recentEntries = viewModel.entries.filter { entry in
            guard let d = df.date(from: String(entry.date.prefix(10))) else { return false }
            return calendar.startOfDay(for: d) >= fourWeeksAgo
        }

        var categoryEntries: [HabitCategory: Int] = [:]
        var categoryHabits: [HabitCategory: Set<String>] = [:]
        for entry in recentEntries {
            categoryEntries[entry.category, default: 0] += 1
            categoryHabits[entry.category, default: []].insert(entry.name)
        }

        var rates: [CategoryRate] = []
        for (cat, count) in categoryEntries {
            let habitCount = categoryHabits[cat]?.count ?? 1
            let possibleCompletions = max(habitCount * 28, 1)
            let rate = min(Double(count) / Double(possibleCompletions), 1.0)
            rates.append(CategoryRate(category: cat, rate: rate))
        }

        return rates.sorted { $0.rate > $1.rate }
    }

    private var dayOfWeekRates: [Double] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        guard let fourWeeksAgo = calendar.date(byAdding: .day, value: -28, to: today) else {
            return Array(repeating: 0.0, count: 7)
        }

        let habits = uniqueHabits
        guard !habits.isEmpty else { return Array(repeating: 0.0, count: 7) }

        // weekday: 1=Sun, 2=Mon ... 7=Sat; remap to Mon=0 .. Sun=6
        var dayCounts = Array(repeating: 0, count: 7)
        for entry in viewModel.entries {
            guard let d = df.date(from: String(entry.date.prefix(10))) else { continue }
            let day = calendar.startOfDay(for: d)
            guard day >= fourWeeksAgo else { continue }
            let wd = calendar.component(.weekday, from: day)
            let idx = (wd + 5) % 7 // Mon=0, Tue=1 ... Sun=6
            dayCounts[idx] += 1
        }

        let possiblePerDay = max(habits.count * 4, 1) // 4 weeks
        return dayCounts.map { min(Double($0) / Double(possiblePerDay), 1.0) }
    }

    private var earnedMilestones: [EarnedMilestone] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let habits = uniqueHabits
        var milestones: [EarnedMilestone] = []
        let today = calendar.startOfDay(for: Date())

        for habitName in habits {
            let habitEntries = viewModel.entries.filter { $0.name == habitName }
            let entryDates = Set(habitEntries.compactMap { df.date(from: String($0.date.prefix(10))) }
                .map { calendar.startOfDay(for: $0) })

            // Calculate streak
            var streak = 0
            var day = today
            while entryDates.contains(day) {
                streak += 1
                guard let prev = calendar.date(byAdding: .day, value: -1, to: day) else { break }
                day = prev
            }

            for tier in MilestoneTier.allCases {
                if streak >= tier.rawValue {
                    let isRecent = streak - tier.rawValue < 3
                    milestones.append(EarnedMilestone(
                        id: "\(habitName)-\(tier.rawValue)",
                        habitName: habitName,
                        tier: tier,
                        isRecent: isRecent
                    ))
                }
            }
        }

        return milestones.sorted { $0.tier > $1.tier }
    }

    // MARK: - Helpers

    private var uniqueHabits: Set<String> {
        Set(viewModel.entries.map { $0.name }).filter { !$0.isEmpty }
    }

    private func daysElapsedInRange(from start: Date, to end: Date) -> Int {
        max((calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1, 1)
    }

    private func categoryColor(for category: HabitCategory) -> Color {
        switch category {
        case .health: return Color.hubAccentRed
        case .mindfulness: return .purple
        case .productivity: return Color.hubAccentYellow
        case .fitness: return .orange
        case .learning: return Color.hubPrimary
        case .selfCare: return .pink
        case .social: return Color.hubAccentGreen
        case .other: return .gray
        }
    }

    private func tierColor(for tier: MilestoneTier) -> Color {
        switch tier {
        case .bronze: return Color(red: 0.80, green: 0.50, blue: 0.20)
        case .silver: return Color(red: 0.75, green: 0.75, blue: 0.78)
        case .gold: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .platinum: return Color(red: 0.44, green: 0.80, blue: 0.93)
        }
    }
}