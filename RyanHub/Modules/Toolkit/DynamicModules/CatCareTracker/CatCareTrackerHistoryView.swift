import SwiftUI

struct CatCareTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CatCareTrackerViewModel

    private var calendarData: [Date: Double] {
        var data: [Date: Double] = [:]
        for entry in viewModel.entries {
            let day = Calendar.current.startOfDay(for: entry.parsedDate)
            data[day, default: 0] += 1
        }
        return data
    }

    private var groupedEntries: [(key: String, entries: [CatCareTrackerEntry])] {
        let sorted = viewModel.entries.sorted { $0.parsedDate > $1.parsedDate }
        var ordered: [String] = []
        var map: [String: [CatCareTrackerEntry]] = [:]
        for entry in sorted {
            let key = entry.dateOnly
            if map[key] == nil {
                ordered.append(key)
                map[key] = []
            }
            map[key]!.append(entry)
        }
        return ordered.map { (key: $0, entries: map[$0]!) }
    }

    private func displayHeader(for dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else { return dateString }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let out = DateFormatter()
        out.dateStyle = .long
        return out.string(from: date)
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
                    entriesContent
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 52))
                .foregroundStyle(Color.hubPrimary.opacity(0.35))
            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    private var entriesContent: some View {
        LazyVStack(spacing: HubLayout.sectionSpacing, pinnedViews: .sectionHeaders) {
            ForEach(groupedEntries, id: \.key) { group in
                Section {
                    VStack(spacing: HubLayout.itemSpacing) {
                        ForEach(group.entries) { entry in
                            entryRow(entry)
                        }
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                } header: {
                    SectionHeader(title: displayHeader(for: group.key))
                        .padding(.horizontal, HubLayout.standardPadding)
                        .padding(.vertical, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AdaptiveColors.background(for: colorScheme))
                }
            }
        }
    }

    private func entryRow(_ entry: CatCareTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.hubPrimary.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.eventType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(entry.eventType.displayName)
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubPrimary)

                        if !entry.detailLine.isEmpty {
                            Text("·")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(entry.detailLine)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                .lineLimit(1)
                        }
                    }

                    Text(entry.formattedDate)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.75))
                        .padding(8)
                        .contentShape(Rectangle())
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }
}