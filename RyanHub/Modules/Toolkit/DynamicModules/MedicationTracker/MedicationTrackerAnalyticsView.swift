import SwiftUI

struct MedicationTrackerAnalyticsView: View {
    let viewModel: MedicationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                adherenceOverviewSection
                weeklyChartSection
                statsGridSection
                streakSection
                heatmapSection
                if !viewModel.adherenceSummaries.isEmpty {
                    perMedicationSection
                }
                if !viewModel.insights.isEmpty {
                    insightsSection
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Sections

    private var adherenceOverviewSection: some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Overall Adherence")
                HStack(spacing: HubLayout.sectionSpacing) {
                    ProgressRingView(
                        progress: viewModel.overallAdherence,
                        current: "\(Int(viewModel.overallAdherence * 100))%",
                        unit: "adherence",
                        color: adherenceColor(viewModel.overallAdherence),
                        size: 100,
                        lineWidth: 10
                    )
                    VStack(alignment: .leading, spacing: 10) {
                        doseStatRow(label: "Taken", value: "\(viewModel.takenCount)", color: Color.hubAccentGreen)
                        doseStatRow(label: "Missed", value: "\(viewModel.missedCount)", color: Color.hubAccentRed)
                        doseStatRow(label: "Skipped", value: "\(viewModel.skippedCount)", color: Color.hubAccentYellow)
                    }
                    Spacer()
                }
            }
        }
    }

    private var weeklyChartSection: some View {
        HubCard {
            ModuleChartView(
                title: "Weekly Doses",
                subtitle: "Taken per day this week",
                dataPoints: viewModel.weeklyChartData,
                style: .bar,
                color: Color.hubPrimary,
                showArea: false
            )
        }
    }

    private var statsGridSection: some View {
        StatGrid {
            StatCard(
                title: "Total Doses",
                value: "\(viewModel.totalDoses)",
                icon: "pills.fill",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Taken",
                value: "\(viewModel.takenCount)",
                icon: "checkmark.circle.fill",
                color: Color.hubAccentGreen
            )
            StatCard(
                title: "Missed",
                value: "\(viewModel.missedCount)",
                icon: "xmark.circle.fill",
                color: Color.hubAccentRed
            )
            StatCard(
                title: "Medications",
                value: "\(viewModel.uniqueMedicationCount)",
                icon: "cross.vial.fill",
                color: Color.hubAccentYellow
            )
        }
    }

    private var streakSection: some View {
        HubCard {
            StreakCounter(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                unit: "days",
                isActiveToday: viewModel.isActiveToday
            )
        }
    }

    private var heatmapSection: some View {
        HubCard {
            CalendarHeatmap(
                title: "Adherence History",
                data: viewModel.heatmapData,
                color: Color.hubPrimary,
                weeks: 12
            )
        }
    }

    private var perMedicationSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Per-Medication Adherence")
            HubCard {
                VStack(spacing: 0) {
                    ForEach(Array(viewModel.adherenceSummaries.enumerated()), id: \.element.medicationName) { index, summary in
                        medicationAdherenceRow(summary)
                        if index < viewModel.adherenceSummaries.count - 1 {
                            Divider()
                                .padding(.horizontal, 0)
                                .opacity(0.4)
                        }
                    }
                }
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Insights")
            InsightsList(insights: viewModel.insights)
        }
    }

    // MARK: - Subviews

    private func doseStatRow(label: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Spacer()
            Text(value)
                .font(.hubCaption)
                .fontWeight(.semibold)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
        }
    }

    private func medicationAdherenceRow(_ summary: MedicationAdherenceSummary) -> some View {
        HStack(spacing: HubLayout.itemSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.medicationName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("\(summary.takenCount) of \(summary.totalCount) doses taken")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            Spacer()
            HStack(spacing: 10) {
                Text("\(summary.adherencePercent)%")
                    .font(.hubHeading)
                    .fontWeight(.bold)
                    .foregroundStyle(summary.isBelowThreshold ? Color.hubAccentRed : Color.hubAccentGreen)
                CompactProgressRing(
                    progress: summary.adherenceRate,
                    color: summary.isBelowThreshold ? Color.hubAccentRed : Color.hubAccentGreen,
                    size: 36
                )
            }
        }
        .padding(.vertical, HubLayout.itemSpacing)
    }

    // MARK: - Helpers

    private func adherenceColor(_ rate: Double) -> Color {
        if rate >= 0.9 { return Color.hubAccentGreen }
        if rate >= 0.8 { return Color.hubAccentYellow }
        return Color.hubAccentRed
    }
}