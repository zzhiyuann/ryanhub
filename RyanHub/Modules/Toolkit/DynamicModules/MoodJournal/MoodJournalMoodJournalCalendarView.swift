import SwiftUI

struct MoodJournalMoodJournalCalendarView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Month calendar grid inspired by 'Year in Pixels' where each day cell is a rounded square color-coded by mood rating using a continuous gradient (deep red=1, orange=3, amber=5, lime=7, green=10, gray with dashed border=no entry). Swipe or arrow buttons for month-to-month navigation. Tapping a day cell expands it into a slide-up detail card showing that day's mood face, emotion chip, energy dots, activity tags, and note in a compact HubCard. Below the calendar grid: three summary stat cards in a horizontal row showing the month's average mood (with trend arrow vs previous month), total check-ins count, and most frequent emotion with its icon. The calendar provides an at-a-glance emotional landscape that makes weekly and monthly mood patterns immediately visible through color clustering.")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }
                }
                ForEach(viewModel.entries) { entry in
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
                        }
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }
}
