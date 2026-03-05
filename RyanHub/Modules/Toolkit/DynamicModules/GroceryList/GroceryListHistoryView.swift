import SwiftUI

struct GroceryListHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GroceryListViewModel

    private var entriesByDate: [(key: String, value: [GroceryListEntry])] {
        let grouped = Dictionary(grouping: viewModel.entries) { $0.dateOnly }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (key: $0.key, value: $0.value.sorted { $0.date > $1.date }) }
    }

    private func sectionHeader(for dateString: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: dateString) else { return dateString }
        if Calendar.current.isDateInToday(d) { return "Today" }
        if Calendar.current.isDateInYesterday(d) { return "Yesterday" }
        let out = DateFormatter()
        out.dateStyle = .medium
        return out.string(from: d)
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing, pinnedViews: []) {
                if viewModel.entries.isEmpty {
                    emptyStateView
                } else {
                    ForEach(entriesByDate, id: \.key) { section in
                        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                            SectionHeader(title: sectionHeader(for: section.key))
                                .padding(.horizontal, HubLayout.standardPadding)

                            ForEach(section.value) { entry in
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

    private func entryCard(_ entry: GroceryListEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(entry.isPurchased ? Color.hubAccentGreen : Color.hubPrimary)
                    .frame(width: 36, height: 36)
                    .background(
                        (entry.isPurchased ? Color.hubAccentGreen : Color.hubPrimary).opacity(0.12)
                    )
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        if entry.isPurchased {
                            Label("Purchased", systemImage: "checkmark.circle.fill")
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentGreen)
                                .labelStyle(.iconOnly)
                        }

                        if entry.isHighPriority {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.hubCaption)
                                .foregroundStyle(Color.hubAccentRed)
                        }
                    }
                }

                Spacer()

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .padding(8)
                        .background(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Image(systemName: "cart.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(Color.hubPrimary.opacity(0.5))

            Text("No entries yet")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Add items to your grocery list to see them here.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
        .padding(.horizontal, HubLayout.standardPadding)
    }
}