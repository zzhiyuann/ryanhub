import SwiftUI

struct SleepTrackerWeekView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: SleepTrackerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Weekly sleep pattern visualization. Shows a 7-day vertical timeline chart where each row is a day (Mon-Sun), and each bar stretches horizontally from bedtime to wake time (e.g., 11pm to 7am), positioned against a time axis. Bars are color-coded by quality rating (muted red for 1, vibrant green for 5). Vertical dashed line marks the user's sleep goal target (8h). Below the chart: a stats row with weekly average hours, average bedtime, average wake time, and bedtime consistency (standard deviation). Tapping any day bar expands an inline detail card showing that night's full entry (duration, quality, mood, notes). Empty days show a ghost bar with 'No entry' label.")
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
