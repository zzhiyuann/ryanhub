import SwiftUI

struct ReadingTrackerHistoryView: View {
    let viewModel: ReadingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var groupedEntries: [(String, [ReadingTrackerEntry])] {
        let sorted = viewModel.entries.sorted { $0.date > $1.date }
        var dict: [String: [ReadingTrackerEntry]] = [:]
        for entry in sorted {
            dict[entry.dateOnly, default: []].append(entry)
        }
        return dict.keys.sorted(by: >).map { ($0, dict[$0]!) }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                CalendarHeatmap(
                    title: "Activity",
                    data: viewModel.calendarData,
                    color: .hubPrimary
                )
                .padding(.horizontal, HubLayout.standardPadding)

                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedEntries, id: \.0) { dateKey, entries in
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: formattedSectionDate(dateKey))
                                .padding(.horizontal, HubLayout.standardPadding)

                            ForEach(entries) { entry in
                                entryCard(entry)
                                    .padding(.horizontal, HubLayout.standardPadding)
                            }
                        }
                    }
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "books.vertical")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    // MARK: - Entry Card

    private func entryCard(_ entry: ReadingTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: entry.genre.icon)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                            .frame(width: 20)

                        Text(entry.bookTitle.isEmpty ? "Untitled" : entry.bookTitle)
                            .font(.hubBody)
                            .fontWeight(.semibold)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            .lineLimit(1)
                    }

                    if !entry.author.isEmpty {
                        Text(entry.author)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if !entry.summaryLine.isEmpty {
                        Text(entry.summaryLine)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if entry.totalPages > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.hubPrimary.opacity(0.15))
                                        .frame(height: 4)
                                    Capsule()
                                        .fill(Color.hubPrimary)
                                        .frame(width: geo.size.width * entry.progressPercent, height: 4)
                                }
                            }
                            .frame(height: 4)

                            Text(entry.progressDisplay)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }

                    HStack(spacing: 10) {
                        statusBadge(entry.status)

                        if entry.hasRating {
                            Text(entry.ratingDisplay)
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentYellow)
                        }

                        Spacer()

                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusBadge(_ status: ReadingStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: 10, weight: .medium))
            Text(status.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(statusColor(status))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(statusColor(status).opacity(0.12))
        .clipShape(Capsule())
    }

    private func statusColor(_ status: ReadingStatus) -> Color {
        switch status {
        case .reading: return Color.hubPrimary
        case .completed: return Color.hubAccentGreen
        case .paused: return Color.hubAccentYellow
        case .wantToRead: return Color.hubAccentYellow.opacity(0.8)
        case .abandoned: return Color.hubAccentRed
        }
    }

    // MARK: - Helpers

    private func formattedSectionDate(_ dateOnly: String) -> String {
        let input = DateFormatter()
        input.dateFormat = "yyyy-MM-dd"
        guard let date = input.date(from: dateOnly) else { return dateOnly }

        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }

        let output = DateFormatter()
        output.dateStyle = .long
        output.timeStyle = .none
        return output.string(from: date)
    }
}