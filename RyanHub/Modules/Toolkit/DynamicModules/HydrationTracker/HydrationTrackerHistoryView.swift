import SwiftUI

struct HydrationTrackerHistoryView: View {
    let viewModel: HydrationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var groupedEntries: [(String, [HydrationTrackerEntry])] {
        let groups = Dictionary(grouping: viewModel.entries) { $0.dayKey }
        return groups
            .sorted { $0.key > $1.key }
            .map { (key, entries) in (key, entries.sorted { $0.date > $1.date }) }
    }

    private func formattedDayKey(_ dayKey: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dayKey) else { return dayKey }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: d)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                if !viewModel.calendarData.isEmpty {
                    CalendarHeatmap(
                        title: "Activity",
                        data: viewModel.calendarData,
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

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Spacer(minLength: 60)
            Image(systemName: "drop.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.hubPrimary.opacity(0.35))
            Text("No entries yet")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Text("Start tracking your hydration to see your history here.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, HubLayout.sectionSpacing)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private var entriesListView: some View {
        LazyVStack(spacing: HubLayout.sectionSpacing, pinnedViews: .sectionHeaders) {
            ForEach(groupedEntries, id: \.0) { dayKey, entries in
                Section {
                    VStack(spacing: HubLayout.itemSpacing) {
                        ForEach(entries) { entry in
                            HydrationEntryRow(entry: entry, colorScheme: colorScheme) {
                                Task { await viewModel.deleteEntry(entry) }
                            }
                        }
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                } header: {
                    HStack {
                        SectionHeader(title: formattedDayKey(dayKey))
                        Spacer()
                        let total = entries.reduce(0.0) { $0 + $1.effectiveOz }
                        Text(String(format: "%.0f oz", total))
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                    .padding(.vertical, 6)
                    .background(AdaptiveColors.background(for: colorScheme))
                }
            }
        }
    }
}

private struct HydrationEntryRow: View {
    let entry: HydrationTrackerEntry
    let colorScheme: ColorScheme
    let onDelete: () -> Void

    var body: some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.beverageType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    HStack(spacing: 6) {
                        Text(entry.formattedTime)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        if entry.effectiveOz != entry.amountOz {
                            Text("·")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(entry.formattedEffectiveOz)
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubPrimary.opacity(0.8))
                        }
                    }
                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.75))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed)
                        .frame(width: 32, height: 32)
                        .background(Color.hubAccentRed.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}