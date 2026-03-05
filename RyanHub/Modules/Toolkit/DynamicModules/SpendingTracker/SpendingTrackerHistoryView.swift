import SwiftUI

struct SpendingTrackerHistoryView: View {
    let viewModel: SpendingTrackerViewModel

    @Environment(\.colorScheme) private var colorScheme

    private var groupedEntries: [(key: String, date: Date, entries: [SpendingTrackerEntry])] {
        let sorted = viewModel.entries.sorted { $0.parsedDate > $1.parsedDate }
        var seen: [String: [SpendingTrackerEntry]] = [:]
        var order: [String] = []
        for entry in sorted {
            if seen[entry.dateOnly] == nil {
                order.append(entry.dateOnly)
                seen[entry.dateOnly] = []
            }
            seen[entry.dateOnly]!.append(entry)
        }
        return order.compactMap { key -> (String, Date, [SpendingTrackerEntry])? in
            guard let entries = seen[key], let first = entries.first else { return nil }
            return (key, first.parsedDate, entries)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing, pinnedViews: []) {
                if viewModel.entries.isEmpty {
                    emptyState
                } else {
                    ForEach(groupedEntries, id: \.key) { group in
                        dateSection(dateKey: group.key, date: group.date, entries: group.entries)
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Date Section

    @ViewBuilder
    private func dateSection(dateKey: String, date: Date, entries: [SpendingTrackerEntry]) -> some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            sectionHeader(dateKey: dateKey, date: date, entries: entries)

            ForEach(entries) { entry in
                entryCard(entry: entry)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(dateKey: String, date: Date, entries: [SpendingTrackerEntry]) -> some View {
        let label = sectionDateLabel(dateKey: dateKey, date: date)
        let total = entries.reduce(0.0) { $0 + $1.amount }

        HStack {
            SectionHeader(title: label)
            Spacer()
            Text(String(format: "$%.2f", total))
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
        }
    }

    private func sectionDateLabel(dateKey: String, date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "TODAY" }
        if cal.isDateInYesterday(date) { return "YESTERDAY" }
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date).uppercased()
    }

    // MARK: - Entry Card

    @ViewBuilder
    private func entryCard(entry: SpendingTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                categoryIcon(entry: entry)

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        if entry.isRecurring {
                            Label("Recurring", systemImage: "arrow.clockwise")
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentYellow)
                                .labelStyle(.iconOnly)
                        }

                        Text(entry.paymentMethod.displayName)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                deleteButton(entry: entry)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    @ViewBuilder
    private func categoryIcon(entry: SpendingTrackerEntry) -> some View {
        ZStack {
            Circle()
                .fill(Color.hubPrimary.opacity(0.15))
                .frame(width: 40, height: 40)
            Image(systemName: entry.category.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.hubPrimary)
        }
    }

    @ViewBuilder
    private func deleteButton(entry: SpendingTrackerEntry) -> some View {
        Button {
            Task { await viewModel.deleteEntry(entry) }
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.hubAccentRed)
                .padding(8)
                .background(Color.hubAccentRed.opacity(0.1), in: Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Spacer(minLength: 60)

            Image(systemName: "creditcard.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))

            Text("No entries yet")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Text("Add your first spending entry to get started.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, HubLayout.standardPadding)
    }
}