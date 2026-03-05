import SwiftUI

struct SleepTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SleepTrackerViewModel

    private var calendarData: [Date: Double] {
        var data: [Date: Double] = [:]
        for entry in viewModel.entries {
            if let date = entry.calendarDate {
                let day = Calendar.current.startOfDay(for: date)
                data[day] = entry.heatmapIntensity
            }
        }
        return data
    }

    private var groupedEntries: [(key: String, entries: [SleepTrackerEntry])] {
        let sorted = viewModel.entries.sorted {
            ($0.calendarDate ?? .distantPast) > ($1.calendarDate ?? .distantPast)
        }
        var result: [(key: String, entries: [SleepTrackerEntry])] = []
        var seen: [String: Int] = [:]
        for entry in sorted {
            let key = entry.formattedDate
            if let idx = seen[key] {
                result[idx].entries.append(entry)
            } else {
                seen[key] = result.count
                result.append((key: key, entries: [entry]))
            }
        }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                if !viewModel.entries.isEmpty {
                    CalendarHeatmap(
                        title: "Activity",
                        data: calendarData,
                        color: .hubPrimary
                    )
                    .padding(.horizontal, HubLayout.standardPadding)
                }

                if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    entriesListView
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 52))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    // MARK: - Entries List

    private var entriesListView: some View {
        VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
            ForEach(groupedEntries, id: \.key) { group in
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: group.key)
                        .padding(.horizontal, HubLayout.standardPadding)

                    ForEach(group.entries) { entry in
                        entryCard(for: entry)
                            .padding(.horizontal, HubLayout.standardPadding)
                    }
                }
            }
        }
    }

    // MARK: - Entry Card

    private func entryCard(for entry: SleepTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Image(systemName: entry.wakeUpMood.icon)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hubPrimary)
                        Text(entry.timeRangeLabel)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }

                    Text(entry.summaryLine)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if entry.sleepDisruptor.isActive {
                        HStack(spacing: 4) {
                            Image(systemName: entry.sleepDisruptor.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(Color.hubAccentYellow)
                            Text(entry.sleepDisruptor.displayName)
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentYellow)
                        }
                    }

                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.hubAccentRed)
                        .padding(6)
                }
            }
        }
    }
}