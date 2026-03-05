import SwiftUI

struct LearningTrackerHistoryView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: LearningTrackerViewModel

    private var heatmapData: [Date: Double] {
        let calendar = Calendar.current
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        var result: [Date: Double] = [:]
        for entry in viewModel.entries {
            if let date = df.date(from: String(entry.date.prefix(10))) {
                let day = calendar.startOfDay(for: date)
                result[day, default: 0] += 1
            }
        }
        return result
    }

    private var groupedEntries: [(String, [LearningTrackerEntry])] {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let grouped = Dictionary(grouping: viewModel.entries) { String($0.date.prefix(10)) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // Calendar Heatmap
                CalendarHeatmap(
                    title: "Activity",
                    data: heatmapData,
                    color: .hubPrimary
                )

                // Grouped entries by date
                ForEach(groupedEntries, id: \.0) { dateStr, entries in
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: dateStr)
                        ForEach(entries) { entry in
                            HubCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.summaryLine)
                                            .font(.hubBody)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Text(entry.date)
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                    }
                                    Spacer()
                                    Button {
                                        Task { await viewModel.deleteEntry(entry) }
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.hubAccentRed.opacity(0.7))
                                    }
                                }
                            }
                        }
                    }
                }

                if viewModel.entries.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 40))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("No entries yet")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}
