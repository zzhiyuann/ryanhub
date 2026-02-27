import SwiftUI

// MARK: - POPO View

/// The main view for the POPO (Proactive Personal Observer) toolkit plugin.
/// Displays a timeline-based view with day overview, chronological events,
/// narrations, nudges, and sensing status controls.
struct PopoView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = PopoViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Header
                header

                // Day navigation bar
                DateNavigationBar(selectedDate: $viewModel.selectedDate)

                // Today overview card
                if viewModel.sensingEnabled {
                    overviewCard
                }

                // Timeline section
                if viewModel.sensingEnabled {
                    timelineSection
                }

                // Sensing status footer
                sensingStatusFooter
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("POPO")
                .font(.hubTitle)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Proactive Personal Observer")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .padding(.top, 8)
    }

    // MARK: - Overview Card

    private var overviewCard: some View {
        let summary = viewModel.daySummary

        return HubCard {
            VStack(spacing: 14) {
                // Title row
                HStack {
                    Text(overviewTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Spacer()
                    Text("\(summary.eventCount) events")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                // Stats grid
                HStack(spacing: 0) {
                    overviewStat(
                        icon: "shoeprints.fill",
                        value: formatSteps(summary.totalSteps),
                        label: "Steps",
                        color: Color(red: 0.2, green: 0.6, blue: 1.0)
                    )

                    overviewDivider

                    overviewStat(
                        icon: "figure.walk",
                        value: topActivity(from: summary.activityBreakdown),
                        label: "Activity",
                        color: Color.hubAccentGreen
                    )

                    overviewDivider

                    overviewStat(
                        icon: "mappin.and.ellipse",
                        value: "\(summary.locationChanges)",
                        label: "Locations",
                        color: Color.hubAccentGreen
                    )

                    overviewDivider

                    overviewStat(
                        icon: "iphone",
                        value: "\(summary.screenEvents)",
                        label: "Screen",
                        color: AdaptiveColors.textSecondary(for: colorScheme)
                    )
                }
            }
        }
    }

    private var overviewTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(viewModel.selectedDate) {
            return "Today's Overview"
        } else if calendar.isDateInYesterday(viewModel.selectedDate) {
            return "Yesterday's Overview"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: viewModel.selectedDate)) Overview"
        }
    }

    private func overviewStat(icon: String, value: String, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
    }

    private var overviewDivider: some View {
        Rectangle()
            .fill(AdaptiveColors.border(for: colorScheme))
            .frame(width: 1, height: 40)
    }

    private func formatSteps(_ steps: Int) -> String {
        if steps >= 1000 {
            let k = Double(steps) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(steps)"
    }

    private func topActivity(from breakdown: [String: Int]) -> String {
        guard let top = breakdown.max(by: { $0.value < $1.value }) else {
            return "None"
        }
        return top.key.capitalized
    }

    // MARK: - Timeline Section

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "TIMELINE")

            let items = viewModel.timelineItems
            if items.isEmpty {
                emptyTimelineState
            } else {
                // Timeline list
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        TimelineEventRow(
                            item: item,
                            isExpanded: viewModel.isExpanded(item.id),
                            isLast: index == items.count - 1
                        ) {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                viewModel.toggleExpanded(item.id)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private var emptyTimelineState: some View {
        HubCard {
            VStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))

                Text("No events yet")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                Text("Events will appear here as sensors collect data")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Sensing Status Footer

    private var sensingStatusFooter: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            // Sensing toggle
            HubCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(viewModel.sensingEnabled ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
                                .frame(width: 8, height: 8)

                            Text("Sensing Engine")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }

                        Text(viewModel.sensingEnabled ? "Actively observing" : "Paused")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Toggle("", isOn: $viewModel.sensingEnabled)
                        .labelsHidden()
                        .tint(Color.hubPrimary)
                }
            }

            // Sync status row (only when sensing is on)
            if viewModel.sensingEnabled {
                HStack(spacing: 12) {
                    // Last sync
                    HStack(spacing: 4) {
                        Image(systemName: "icloud.and.arrow.up.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Synced \(viewModel.lastSyncTimeString ?? "never")")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    // Pending count + sync button
                    if viewModel.engine.pendingEventCount > 0 {
                        Button {
                            Task { await viewModel.syncNow() }
                        } label: {
                            HStack(spacing: 4) {
                                Text("\(viewModel.engine.pendingEventCount) pending")
                                    .font(.system(size: 11, weight: .medium))
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundStyle(Color.hubPrimary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    PopoView()
}
