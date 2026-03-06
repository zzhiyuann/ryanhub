import SwiftUI

struct MoodJournalTrendsView: View {
    let viewModel: MoodJournalViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var emotionColors: [Emotion: Color] {
        [
            .happy: Color.hubAccentYellow,
            .calm: .cyan,
            .excited: .orange,
            .grateful: .pink,
            .neutral: Color.hubPrimary,
            .anxious: .purple,
            .sad: .blue,
            .angry: Color.hubAccentRed,
            .stressed: .indigo,
            .tired: Color.hubAccentYellow.opacity(0.6)
        ]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                statsOverview
                moodTrendChart
                weeklyComparison
                emotionDistribution
                energyMoodCorrelation
                streakSection
                insightsSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Stats Overview

    private var statsOverview: some View {
        StatGrid {
            StatCard(
                title: "This Week",
                value: String(format: "%.1f", viewModel.weeklyAverage),
                icon: "chart.line.uptrend.xyaxis",
                trend: StatTrend.from(change: viewModel.weeklyTrend),
                color: Color.hubPrimary
            )
            StatCard(
                title: "Best Day",
                value: viewModel.bestDayOfWeek,
                icon: "star.fill",
                color: Color.hubAccentYellow
            )
            StatCard(
                title: "Current Streak",
                value: "\(viewModel.currentStreak)",
                icon: "flame.fill",
                color: Color.hubAccentRed
            )
            StatCard(
                title: "Top Emotion",
                value: viewModel.topEmotion?.displayName ?? "N/A",
                icon: viewModel.topEmotion?.icon ?? "face.dashed",
                color: Color.hubAccentGreen
            )
        }
    }

    // MARK: - 30-Day Mood Trend

    private var moodTrendChart: some View {
        VStack(spacing: 0) {
            if viewModel.chartData.isEmpty {
                emptyChartPlaceholder(message: "Check in daily to see your mood trend")
            } else {
                ModuleChartView(
                    title: "30-Day Mood Trend",
                    subtitle: "Daily average rating",
                    dataPoints: viewModel.chartData,
                    style: .line,
                    color: Color.hubPrimary,
                    showArea: true
                )
            }
        }
    }

    // MARK: - Weekly Comparison

    private var weeklyComparison: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Weekly Comparison")

            HubCard {
                HStack(spacing: HubLayout.itemSpacing) {
                    weekBar(
                        label: "Last Week",
                        value: viewModel.previousWeekAverage,
                        maxValue: 10,
                        color: AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4)
                    )
                    weekBar(
                        label: "This Week",
                        value: viewModel.weeklyAverage,
                        maxValue: 10,
                        color: Color.hubPrimary
                    )
                }
                .padding(.vertical, 4)

                if abs(viewModel.weeklyTrend) > 0.01 {
                    HStack {
                        Spacer()
                        let trending = viewModel.weeklyTrend > 0
                        Label(
                            String(format: "%@%.1f from last week", trending ? "+" : "", viewModel.weeklyTrend),
                            systemImage: trending ? "arrow.up.right" : "arrow.down.right"
                        )
                        .font(.hubCaption)
                        .foregroundStyle(trending ? Color.hubAccentGreen : Color.hubAccentRed)
                        Spacer()
                    }
                }
            }
        }
    }

    private func weekBar(label: String, value: Double, maxValue: Double, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(String(format: "%.1f", value))
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            GeometryReader { geo in
                let fraction = maxValue > 0 ? min(value / maxValue, 1.0) : 0
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 6)
                        .fill(color)
                        .frame(height: geo.size.height * fraction)
                }
            }
            .frame(height: 100)

            Text(label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Emotion Distribution

    private var emotionDistribution: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Emotion Distribution")

            let counts = viewModel.emotionCounts
            let total = counts.values.reduce(0, +)

            if total == 0 {
                emptyChartPlaceholder(message: "Track your emotions to see distribution")
            } else {
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        // Ring visualization
                        emotionRing(counts: counts, total: total)
                            .frame(height: 160)
                            .frame(maxWidth: .infinity)

                        // Legend bars
                        let sorted = counts.sorted { $0.value > $1.value }
                        ForEach(sorted.prefix(6), id: \.key) { emotion, count in
                            emotionRow(emotion: emotion, count: count, total: total)
                        }
                    }
                }
            }
        }
    }

    private func emotionRing(counts: [Emotion: Int], total: Int) -> some View {
        let sorted = counts.sorted { $0.value > $1.value }

        return ZStack {
            ForEach(Array(sorted.enumerated()), id: \.element.key) { index, item in
                let fraction = Double(item.value) / Double(total)
                let startAngle = ringStartAngle(for: index, in: sorted, total: total)
                let endAngle = startAngle + Angle(degrees: fraction * 360)
                let color = emotionColors[item.key] ?? Color.hubPrimary

                Circle()
                    .trim(from: CGFloat(startAngle.degrees / 360), to: CGFloat(endAngle.degrees / 360))
                    .stroke(color, style: StrokeStyle(lineWidth: 24, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }

            if let top = viewModel.topEmotion {
                VStack(spacing: 2) {
                    Image(systemName: top.icon)
                        .font(.title2)
                        .foregroundStyle(emotionColors[top] ?? Color.hubPrimary)
                    Text(top.displayName)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
            }
        }
        .padding(20)
    }

    private func ringStartAngle(for index: Int, in sorted: [(key: Emotion, value: Int)], total: Int) -> Angle {
        var angle = 0.0
        for i in 0..<index {
            angle += Double(sorted[i].value) / Double(total) * 360
        }
        return Angle(degrees: angle)
    }

    private func emotionRow(emotion: Emotion, count: Int, total: Int) -> some View {
        let pct = Double(count) / Double(total)
        let color = emotionColors[emotion] ?? Color.hubPrimary

        return HStack(spacing: 10) {
            Image(systemName: emotion.icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 20)

            Text(emotion.displayName)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .frame(width: 70, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color.opacity(0.15))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(color)
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 8)

            Text("\(Int(pct * 100))%")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .frame(width: 36, alignment: .trailing)
        }
    }

    // MARK: - Energy-Mood Correlation

    private var energyMoodCorrelation: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Energy & Mood")

            let corr = viewModel.energyMoodCorrelation
            let entries30 = recentEntries

            if entries30.count < 3 {
                emptyChartPlaceholder(message: "Need at least 3 entries to analyze correlation")
            } else {
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        // Correlation indicator
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Correlation")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Text(correlationLabel(corr))
                                    .font(.hubHeading)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                            Spacer()
                            Text(String(format: "r = %.2f", corr))
                                .font(.hubBody)
                                .foregroundStyle(correlationColor(corr))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(correlationColor(corr).opacity(0.12))
                                .clipShape(Capsule())
                        }

                        // Scatter plot
                        scatterPlot(entries: entries30)
                            .frame(height: 180)
                    }
                }
            }
        }
    }

    private var recentEntries: [MoodJournalEntry] {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -30, to: cal.startOfDay(for: Date())) ?? Date()
        return viewModel.entries.filter { entry in
            guard let d = entry.parsedDate else { return false }
            return d >= cutoff
        }
    }

    private func scatterPlot(entries: [MoodJournalEntry]) -> some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let padX: CGFloat = 30
            let padY: CGFloat = 20

            ZStack(alignment: .bottomLeading) {
                // Grid lines
                ForEach(0..<5, id: \.self) { i in
                    let y = padY + (h - padY * 2) * CGFloat(i) / 4
                    Path { p in
                        p.move(to: CGPoint(x: padX, y: y))
                        p.addLine(to: CGPoint(x: w, y: y))
                    }
                    .stroke(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.1), lineWidth: 0.5)
                }

                // Axis labels
                VStack {
                    Text("10")
                        .font(.system(size: 9))
                    Spacer()
                    Text("Mood")
                        .font(.system(size: 9))
                        .rotationEffect(.degrees(-90))
                    Spacer()
                    Text("1")
                        .font(.system(size: 9))
                }
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .frame(width: padX - 4)
                .padding(.vertical, padY)

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Energy →")
                            .font(.system(size: 9))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .padding(.trailing, 4)
                }

                // Data points
                ForEach(entries) { entry in
                    let xFrac = CGFloat(entry.energyLevel - 1) / 9.0
                    let yFrac = CGFloat(entry.rating - 1) / 9.0
                    let x = padX + (w - padX - 8) * xFrac
                    let y = padY + (h - padY * 2) * (1 - yFrac)

                    Circle()
                        .fill(moodDotColor(rating: entry.rating).opacity(0.7))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)
                }
            }
        }
    }

    private func moodDotColor(rating: Int) -> Color {
        switch rating {
        case 1...3: return Color.hubAccentRed
        case 4...6: return Color.hubAccentYellow
        case 7...10: return Color.hubAccentGreen
        default: return Color.hubPrimary
        }
    }

    private func correlationLabel(_ r: Double) -> String {
        switch abs(r) {
        case 0.7...: return r > 0 ? "Strong Positive" : "Strong Negative"
        case 0.3...: return r > 0 ? "Moderate Positive" : "Moderate Negative"
        default: return "Weak"
        }
    }

    private func correlationColor(_ r: Double) -> Color {
        if abs(r) < 0.3 { return AdaptiveColors.textSecondary(for: colorScheme) }
        return r > 0 ? Color.hubAccentGreen : Color.hubAccentRed
    }

    // MARK: - Streaks

    private var streakSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Streaks")
            StreakCounter(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                unit: "days",
                isActiveToday: viewModel.hasCheckedInToday
            )
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            if !viewModel.insights.isEmpty {
                SectionHeader(title: "Insights")
                InsightsList(insights: viewModel.insights)
            }
        }
    }

    // MARK: - Helpers

    private func emptyChartPlaceholder(message: String) -> some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.largeTitle)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
                Text(message)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.sectionSpacing)
        }
    }
}