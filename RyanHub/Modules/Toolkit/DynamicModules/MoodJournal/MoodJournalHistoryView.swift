import SwiftUI

struct MoodJournalHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    private var groupedEntries: [(key: String, entries: [MoodJournalEntry])] {
        let grouped = Dictionary(grouping: viewModel.entries, by: \.dayKey)
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HubLayout.sectionSpacing, pinnedViews: .sectionHeaders) {
                if !viewModel.calendarData.isEmpty {
                    CalendarHeatmap(
                        title: "Activity",
                        data: viewModel.calendarData,
                        color: .hubPrimary
                    )
                    .padding(.horizontal, HubLayout.standardPadding)
                }

                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedEntries, id: \.key) { section in
                        LazyVStack(alignment: .leading, spacing: HubLayout.itemSpacing, pinnedViews: .sectionHeaders) {
                            Section {
                                ForEach(section.entries) { entry in
                                    entryCard(entry)
                                }
                            } header: {
                                SectionHeader(title: formattedDayKey(section.key))
                                    .padding(.horizontal, HubLayout.standardPadding)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AdaptiveColors.background(for: colorScheme))
                            }
                        }
                    }
                }
            }
            .padding(.top, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.sectionSpacing)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    @ViewBuilder
    private func entryCard(_ entry: MoodJournalEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                Text(entry.moodEmoji)
                    .font(.system(size: 32))

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    HStack(spacing: 8) {
                        Label(entry.energyLabel, systemImage: "bolt.fill")
                            .foregroundStyle(Color.hubAccentYellow)
                        Label(entry.anxietyLabel, systemImage: "waveform.path")
                            .foregroundStyle(entry.anxietyLevel >= 7 ? Color.hubAccentRed : AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .font(.hubCaption)

                    if entry.hasNotes {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }

                    Text(entry.formattedDate)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .padding(.top, 2)
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                        .padding(8)
                }
            }
        }
        .padding(.horizontal, HubLayout.standardPadding)
    }

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "face.smiling")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    private func formattedDayKey(_ key: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: key) else { return key }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}