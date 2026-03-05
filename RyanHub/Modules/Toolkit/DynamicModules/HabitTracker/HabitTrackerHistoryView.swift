import SwiftUI

struct HabitTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HabitTrackerViewModel

    private var groupedEntries: [(key: String, entries: [HabitTrackerEntry])] {
        let sorted = viewModel.entries.sorted {
            ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast)
        }
        var result: [(key: String, entries: [HabitTrackerEntry])] = []
        var indexMap: [String: Int] = [:]
        for entry in sorted {
            let key = entry.dateOnly
            if let idx = indexMap[key] {
                result[idx].entries.append(entry)
            } else {
                indexMap[key] = result.count
                result.append((key: key, entries: [entry]))
            }
        }
        return result
    }

    private func sectionTitle(for dateString: String) -> String {
        guard let date = dateString.asCalendarDate else { return dateString }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: date)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 72)
    }

    private var entriesList: some View {
        ForEach(groupedEntries, id: \.key) { group in
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: sectionTitle(for: group.key))
                ForEach(group.entries) { entry in
                    entryCard(for: entry)
                }
            }
        }
    }

    private func entryCard(for entry: HabitTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: entry.category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Image(systemName: entry.timeOfDay.icon)
                            .font(.system(size: 11))
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                    }
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if !entry.notes.isEmpty {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hubAccentRed)
                        .padding(8)
                        .background(Color.hubAccentRed.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}