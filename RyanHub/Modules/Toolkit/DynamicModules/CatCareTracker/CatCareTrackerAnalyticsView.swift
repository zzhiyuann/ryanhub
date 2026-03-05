import SwiftUI

@MainActor
struct CatCareTrackerAnalyticsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CatCareTrackerViewModel

    private var entries: [CatCareTrackerEntry] { viewModel.entries }

    private var feedingCount: Int { entries.filter { $0.isFeedingEvent }.count }
    private var vetVisitCount: Int { entries.filter { $0.isVetEvent }.count }
    private var weightCheckCount: Int { entries.filter { $0.isWeightEvent }.count }
    private var symptomCount: Int { entries.filter { $0.isSymptomEvent }.count }
    private var medicationCount: Int { entries.filter { $0.isMedicationEvent }.count }

    private var totalCost: Double { entries.reduce(0) { $0 + $1.cost } }

    private var latestWeight: Double? {
        entries
            .filter { $0.isWeightEvent && $0.catWeight > 0 }
            .sorted { $0.parsedDate > $1.parsedDate }
            .first?.catWeight
    }

    private var todayFeedingCount: Int { entries.filter { $0.isFeedingEvent && $0.isToday }.count }

    private var positiveMoodPct: Int {
        guard !entries.isEmpty else { return 0 }
        let positive = entries.filter { $0.catMood.isPositive }.count
        return Int(Double(positive) / Double(entries.count) * 100)
    }

    private var weeklyChartData: [ChartDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        return (0..<7).reversed().map { offset in
            let date = calendar.date(byAdding: .day, value: -offset, to: now) ?? now
            let count = entries.filter { calendar.isDate($0.parsedDate, inSameDayAs: date) }.count
            let label = date.formatted(.dateTime.weekday(.abbreviated))
            return ChartDataPoint(label: label, value: Double(count))
        }
    }

    private var heatmapData: [Date: Double] {
        let calendar = Calendar.current
        var data: [Date: Double] = [:]
        for entry in entries {
            let day = calendar.startOfDay(for: entry.parsedDate)
            data[day, default: 0] += 1
        }
        return data
    }

    private var currentStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var check = calendar.startOfDay(for: Date())
        while true {
            let hasEntry = entries.contains { calendar.isDate($0.parsedDate, inSameDayAs: check) }
            guard hasEntry else { break }
            streak += 1
            check = calendar.date(byAdding: .day, value: -1, to: check) ?? check
        }
        return streak
    }

    private var longestStreak: Int {
        let calendar = Calendar.current
        let days = Set(entries.map { calendar.startOfDay(for: $0.parsedDate) }).sorted()
        guard days.count > 1 else { return days.isEmpty ? 0 : 1 }
        var longest = 1
        var current = 1
        for i in 1..<days.count {
            let diff = calendar.dateComponents([.day], from: days[i - 1], to: days[i]).day ?? 0
            if diff == 1 {
                current += 1
                longest = max(longest, current)
            } else {
                current = 1
            }
        }
        return longest
    }

    private var isActiveToday: Bool {
        entries.contains { $0.isToday }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing) {

                ModuleChartView(
                    title: "Weekly Events",
                    subtitle: "Care events logged per day",
                    dataPoints: weeklyChartData,
                    style: .bar,
                    color: Color.hubPrimary,
                    showArea: false
                )

                HubCard {
                    StreakCounter(
                        currentStreak: currentStreak,
                        longestStreak: longestStreak,
                        unit: "days",
                        isActiveToday: isActiveToday
                    )
                }

                SectionHeader(title: "Event Breakdown")
                StatGrid {
                    StatCard(
                        title: "Feedings",
                        value: "\(feedingCount)",
                        icon: EventType.feeding.icon,
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Vet Visits",
                        value: "\(vetVisitCount)",
                        icon: EventType.vetVisit.icon,
                        color: Color.hubAccentRed
                    )
                    StatCard(
                        title: "Weight Checks",
                        value: "\(weightCheckCount)",
                        icon: EventType.weightCheck.icon,
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Symptoms",
                        value: "\(symptomCount)",
                        icon: EventType.symptom.icon,
                        color: Color.hubAccentYellow
                    )
                }

                SectionHeader(title: "Health Summary")
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        healthRow(
                            icon: "fork.knife",
                            iconColor: Color.hubPrimary,
                            label: "Today's Feedings",
                            value: "\(todayFeedingCount)"
                        )

                        Divider().opacity(0.3)

                        if let weight = latestWeight {
                            healthRow(
                                icon: "scalemass.fill",
                                iconColor: Color.hubAccentGreen,
                                label: "Latest Weight",
                                value: "\(String(format: "%.1f", weight)) lbs"
                            )
                            Divider().opacity(0.3)
                        }

                        healthRow(
                            icon: "heart.fill",
                            iconColor: Color.hubAccentRed,
                            label: "Positive Mood",
                            value: "\(positiveMoodPct)%",
                            valueColor: positiveMoodPct >= 70 ? Color.hubAccentGreen : Color.hubAccentYellow
                        )

                        Divider().opacity(0.3)

                        healthRow(
                            icon: "pills.fill",
                            iconColor: .purple,
                            label: "Medications",
                            value: "\(medicationCount)"
                        )

                        Divider().opacity(0.3)

                        healthRow(
                            icon: "dollarsign.circle.fill",
                            iconColor: Color.hubAccentYellow,
                            label: "Total Care Costs",
                            value: "$\(String(format: "%.2f", totalCost))"
                        )
                    }
                }

                CalendarHeatmap(
                    title: "Care Activity",
                    data: heatmapData,
                    color: Color.hubPrimary,
                    weeks: 12
                )

                if !viewModel.insights.isEmpty {
                    SectionHeader(title: "Insights")
                    InsightsList(insights: viewModel.insights)
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    @ViewBuilder
    private func healthRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color? = nil
    ) -> some View {
        HStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 20)
            Text(label)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.hubBody)
                .fontWeight(.semibold)
                .foregroundStyle(valueColor ?? AdaptiveColors.textPrimary(for: colorScheme))
        }
    }
}