import SwiftUI

// MARK: - PlantCareTrackerDashboardView

struct PlantCareTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel

    // MARK: Computed from entries

    private var allEntries: [PlantCareTrackerEntry] { viewModel.entries }

    private var todayEntries: [PlantCareTrackerEntry] {
        let today = Calendar.current.startOfDay(for: Date())
        return allEntries.filter { Calendar.current.isDate($0.parsedDate, inSameDayAs: today) }
    }

    private var recentEntries: [PlantCareTrackerEntry] {
        Array(allEntries.sorted { $0.parsedDate > $1.parsedDate }.prefix(5))
    }

    private var uniquePlants: Set<String> {
        Set(allEntries.map { $0.displayPlantName })
    }

    private var wateringSessionsThisWeek: Int {
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return allEntries.filter { $0.parsedDate >= weekAgo && $0.careType == .water }.count
    }

    private var averageHealthScore: Double {
        guard !allEntries.isEmpty else { return 0 }
        let total = allEntries.reduce(0) { $0 + $1.healthScore }
        return Double(total) / Double(allEntries.count)
    }

    private var currentWateringStreak: Int {
        var streak = 0
        var checkDate = Calendar.current.startOfDay(for: Date())
        let calendar = Calendar.current
        let wateringDays = Set(
            allEntries.filter { $0.careType == .water }.map { $0.dateOnly }
        )
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        while true {
            let key = fmt.string(from: checkDate)
            if wateringDays.contains(key) {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }
        return streak
    }

    private var longestStreak: Int {
        guard !allEntries.isEmpty else { return 0 }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        let waterDays = Set(allEntries.filter { $0.careType == .water }.map { $0.dateOnly })
        let sorted = waterDays.sorted()
        var best = 0
        var current = 0
        var prevDate: Date?
        for key in sorted {
            guard let d = fmt.date(from: key) else { continue }
            if let prev = prevDate,
               Calendar.current.dateComponents([.day], from: prev, to: d).day == 1 {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            prevDate = d
        }
        return best
    }

    private var isActiveToday: Bool { !todayEntries.isEmpty }

    private var careTypeDistribution: [(CareType, Int)] {
        CareType.allCases.compactMap { type in
            let count = allEntries.filter { $0.careType == type }.count
            return count > 0 ? (type, count) : nil
        }.sorted { $0.1 > $1.1 }
    }

    private var mostCaredPlant: String? {
        let counts = Dictionary(grouping: allEntries, by: { $0.displayPlantName })
            .mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var healthScoreColor: Color {
        switch averageHealthScore {
        case 4...: return .hubAccentGreen
        case 3..<4: return .hubPrimary
        case 2..<3: return .hubAccentYellow
        default: return .hubAccentRed
        }
    }

    // MARK: Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                statsSection
                todayOverviewSection
                plantHealthSection
                careActivitySection
                recentEntriesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: Stats Section

    private var statsSection: some View {
        StatGrid {
            StatCard(
                title: "Plants Tracked",
                value: "\(uniquePlants.count)",
                icon: "leaf.fill",
                color: .hubAccentGreen
            )
            StatCard(
                title: "Waterings / Week",
                value: "\(wateringSessionsThisWeek)",
                icon: "drop.fill",
                color: Color(red: 0.2, green: 0.6, blue: 1.0)
            )
            StatCard(
                title: "Avg Health",
                value: String(format: "%.1f", averageHealthScore),
                icon: "heart.fill",
                color: healthScoreColor
            )
            StatCard(
                title: "Total Sessions",
                value: "\(allEntries.count)",
                icon: "checkmark.circle.fill",
                color: .hubPrimary
            )
        }
    }

    // MARK: Today Overview

    private var todayOverviewSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today")
            HubCard {
                if todayEntries.isEmpty {
                    emptyTodayView
                } else {
                    todayActivityGrid
                }
            }
        }
    }

    private var emptyTodayView: some View {
        HStack(spacing: 12) {
            Image(systemName: "leaf")
                .font(.system(size: 28))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            VStack(alignment: .leading, spacing: 4) {
                Text("No care logged today")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("Your plants are waiting for some love")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            Spacer()
        }
        .padding(HubLayout.standardPadding)
    }

    private var todayActivityGrid: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            let grouped = Dictionary(grouping: todayEntries, by: { $0.careType })
            ForEach(CareType.allCases.filter { grouped[$0] != nil }, id: \.id) { type in
                let count = grouped[type]?.count ?? 0
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(careTypeColor(type).opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: type.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(careTypeColor(type))
                    }
                    Text(type.displayName)
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

    // MARK: Plant Health Section

    private var plantHealthSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Plant Health & Streak")
            HStack(spacing: HubLayout.itemSpacing) {
                HubCard {
                    VStack(spacing: 8) {
                        ProgressRingView(
                            progress: min(averageHealthScore / 5.0, 1.0),
                            current: String(format: "%.1f", averageHealthScore),
                            unit: "/5",
                            goal: "Health Score",
                            color: healthScoreColor,
                            size: 100,
                            lineWidth: 9
                        )
                    }
                    .padding(HubLayout.standardPadding)
                    .frame(maxWidth: .infinity)
                }

                HubCard {
                    StreakCounter(
                        currentStreak: currentWateringStreak,
                        longestStreak: longestStreak,
                        unit: "days",
                        isActiveToday: isActiveToday
                    )
                    .padding(HubLayout.standardPadding)
                }
            }
        }
    }

    // MARK: Care Activity

    private var careActivitySection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Care Breakdown")
            HubCard {
                VStack(spacing: HubLayout.itemSpacing) {
                    if let star = mostCaredPlant {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(Color.hubAccentYellow)
                                .font(.system(size: 14))
                            Text("Most Loved: \(star)")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Spacer()
                        }
                    }
                    ForEach(careTypeDistribution.prefix(4), id: \.0.id) { item in
                        let (type, count) = item
                        let fraction = allEntries.isEmpty ? 0.0 : Double(count) / Double(allEntries.count)
                        VStack(spacing: 4) {
                            HStack {
                                Image(systemName: type.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(careTypeColor(type))
                                    .frame(width: 20)
                                Text(type.displayName)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Spacer()
                                Text("\(count)")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(careTypeColor(type).opacity(0.12))
                                        .frame(height: 5)
                                    Capsule()
                                        .fill(careTypeColor(type))
                                        .frame(width: geo.size.width * fraction, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                }
                .padding(HubLayout.standardPadding)
            }
        }
    }

    // MARK: Recent Entries

    private var recentEntriesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Recent Care")
            if recentEntries.isEmpty {
                HubCard {
                    Text("No care sessions logged yet.")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(HubLayout.standardPadding)
                }
            } else {
                VStack(spacing: HubLayout.itemSpacing) {
                    ForEach(recentEntries) { entry in
                        recentEntryRow(entry)
                    }
                }
            }
        }
    }

    private func recentEntryRow(_ entry: PlantCareTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(careTypeColor(entry.careType).opacity(0.15))
                        .frame(width: 42, height: 42)
                    Image(systemName: entry.careType.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(careTypeColor(entry.careType))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    HStack(spacing: 6) {
                        Image(systemName: entry.healthScoreIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(healthColor(entry.healthScore))
                        Text(entry.healthScoreLabel)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("·")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text(entry.formattedDateShort)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }
                Spacer()
                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
                .buttonStyle(.plain)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: Helpers

    private func careTypeColor(_ type: CareType) -> Color {
        switch type {
        case .water: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .fertilize: return .hubAccentGreen
        case .mist: return Color(red: 0.4, green: 0.8, blue: 0.9)
        case .prune: return .hubAccentYellow
        case .repot: return Color(red: 0.8, green: 0.5, blue: 0.2)
        case .rotate: return .hubPrimary
        }
    }

    private func healthColor(_ score: Int) -> Color {
        switch score {
        case 1, 2: return .hubAccentRed
        case 3: return .hubAccentYellow
        default: return .hubAccentGreen
        }
    }
}