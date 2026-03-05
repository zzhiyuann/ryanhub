import SwiftUI

struct MedicationTrackerHistoryView: View {
    let viewModel: MedicationTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var groupedEntries: [(String, [MedicationTrackerEntry])] {
        let sorted = viewModel.entries.sorted {
            ($0.parsedDate ?? Date.distantPast) > ($1.parsedDate ?? Date.distantPast)
        }
        var groups: [(String, [MedicationTrackerEntry])] = []
        var indexMap: [String: Int] = [:]
        for entry in sorted {
            let key = entry.dateOnly
            if let idx = indexMap[key] {
                groups[idx].1.append(entry)
            } else {
                indexMap[key] = groups.count
                groups.append((key, [entry]))
            }
        }
        return groups
    }

    private func sectionLabel(for dateString: String) -> String {
        let parser = DateFormatter()
        parser.dateFormat = "yyyy-MM-dd"
        guard let date = parser.date(from: dateString) else { return dateString }
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: date)
    }

    private func statusColor(for status: DoseStatus) -> Color {
        switch status {
        case .taken:   return Color.hubAccentGreen
        case .skipped: return Color.hubAccentYellow
        case .missed:  return Color.hubAccentRed
        case .delayed: return Color.hubPrimary
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                CalendarHeatmap(
                    title: "Activity",
                    data: viewModel.calendarData,
                    color: .hubPrimary
                )
                .padding(.horizontal, HubLayout.standardPadding)

                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    entriesList
                }
            }
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "pills")
                .font(.system(size: 52))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
            Text("No entries yet")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 64)
    }

    private var entriesList: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            ForEach(groupedEntries, id: \.0) { dateKey, entries in
                VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                    SectionHeader(title: sectionLabel(for: dateKey))
                        .padding(.horizontal, HubLayout.standardPadding)

                    VStack(spacing: HubLayout.itemSpacing) {
                        ForEach(entries) { entry in
                            entryCard(entry)
                        }
                    }
                    .padding(.horizontal, HubLayout.standardPadding)
                }
            }
        }
    }

    private func entryCard(_ entry: MedicationTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                Image(systemName: entry.status.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(statusColor(for: entry.status))
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Image(systemName: entry.timeOfDay.icon)
                            .font(.system(size: 11))
                        Text(entry.timeOfDay.displayName)
                            .font(.hubCaption)
                        Text("·")
                            .font(.hubCaption)
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                    }
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if entry.withFood {
                        HStack(spacing: 4) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 11))
                            Text("Taken with food")
                                .font(.hubCaption)
                        }
                        .foregroundStyle(Color.hubAccentGreen.opacity(0.85))
                    }

                    if entry.hasSideEffects {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                            Text(entry.sideEffects)
                                .font(.hubCaption)
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.hubAccentYellow)
                    }

                    if !entry.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.75))
                        .padding(6)
                }
            }
        }
    }
}