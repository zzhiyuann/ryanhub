import SwiftUI

struct PlantCareTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: PlantCareTrackerViewModel

    private var groupedEntries: [(String, [PlantCareTrackerEntry])] {
        let sorted = viewModel.entries.sorted { $0.parsedDate > $1.parsedDate }
        var groups: [(String, [PlantCareTrackerEntry])] = []
        var seen: [String: Int] = [:]
        for entry in sorted {
            let key = entry.dateOnly
            if let idx = seen[key] {
                groups[idx].1.append(entry)
            } else {
                seen[key] = groups.count
                groups.append((key, [entry]))
            }
        }
        return groups
    }

    private var sectionDateLabel: (String) -> String {
        { dateOnly in
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            guard let d = f.date(from: dateOnly) else { return dateOnly }
            if Calendar.current.isDateInToday(d) { return "Today" }
            if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
            let out = DateFormatter()
            out.dateStyle = .medium
            out.timeStyle = .none
            return out.string(from: d)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing, pinnedViews: []) {
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
                    ForEach(groupedEntries, id: \.0) { dateKey, entries in
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: sectionDateLabel(dateKey))
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

    private func entryCard(_ entry: PlantCareTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.careType.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    HStack(spacing: 8) {
                        Label(entry.location.displayName, systemImage: entry.location.icon)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Text("·")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Label(entry.healthScoreLabel, systemImage: entry.healthScoreIcon)
                            .font(.hubCaption)
                            .foregroundStyle(healthColor(entry.healthScore))
                    }

                    if entry.isWaterEvent {
                        Label(entry.waterAmount.displayName, systemImage: entry.waterAmount.icon)
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubPrimary.opacity(0.8))
                    }

                    if !entry.notes.isEmpty {
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

                Spacer(minLength: 0)

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.8))
                        .padding(8)
                        .background(Color.hubAccentRed.opacity(0.1), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Spacer(minLength: 60)
            Image(systemName: "leaf.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(Color.hubPrimary.opacity(0.4))
            Text("No entries yet")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            Text("Start tracking your plant care to see history here.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, HubLayout.sectionSpacing)
            Spacer(minLength: 60)
        }
    }

    private func healthColor(_ score: Int) -> Color {
        switch score {
        case 1, 2: return .hubAccentRed
        case 3: return .hubAccentYellow
        case 4, 5: return .hubAccentGreen
        default: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }
}