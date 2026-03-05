import SwiftUI

struct CommuteTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CommuteTrackerViewModel

    private var groupedEntries: [(String, [CommuteTrackerEntry])] {
        let sorted = viewModel.entries.sorted { $0.date > $1.date }
        var keys: [String] = []
        var dict: [String: [CommuteTrackerEntry]] = [:]
        for entry in sorted {
            let key = entry.dateOnly
            if dict[key] == nil {
                keys.append(key)
                dict[key] = []
            }
            dict[key]?.append(entry)
        }
        return keys.compactMap { key in dict[key].map { (key, $0) } }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
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
                            SectionHeader(title: sectionTitle(for: dateKey))
                                .padding(.horizontal, HubLayout.standardPadding)

                            ForEach(entries) { entry in
                                entryCard(for: entry)
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

    private func entryCard(for entry: CommuteTrackerEntry) -> some View {
        HubCard {
            HStack(alignment: .top, spacing: HubLayout.itemSpacing) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: entry.direction.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.hubPrimary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 6) {
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        if entry.hasDelay {
                            Text("+\(entry.delayMinutes)m delay")
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentRed)
                        }

                        Text(entry.trafficEmoji)
                            .font(.hubCaption)
                    }

                    HStack(spacing: 8) {
                        Label(entry.formattedCost, systemImage: "dollarsign.circle")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Label(entry.experienceLabel, systemImage: "star.fill")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentYellow)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubAccentRed.opacity(0.75))
                        .padding(8)
                        .background(Color.hubAccentRed.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "car.fill")
                .font(.system(size: 52))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.35))

            Text("No entries yet")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Track a commute to see your history here.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
        .padding(.horizontal, HubLayout.standardPadding)
    }

    private func sectionTitle(for dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return dateKey }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let out = DateFormatter()
        out.dateStyle = .long
        out.timeStyle = .none
        return out.string(from: date)
    }
}