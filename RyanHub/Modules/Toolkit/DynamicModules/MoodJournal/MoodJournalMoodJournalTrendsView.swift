import SwiftUI

struct MoodJournalMoodJournalTrendsView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Insights and analytics screen. Top: streak badge showing current consecutive check-in days with a flame icon, plus longest streak record. Below: a smooth line chart plotting mood ratings over the last 30 days with a dashed trend line overlay and colored zones (green band for 8-10, yellow 5-7, red 1-4). Weekly comparison card showing this week's average vs last week with a prominent percentage change arrow (green up or red down). Mood distribution horizontal bar chart breaking entries into four ranges: Great (8-10), Good (6-7), Okay (4-5), Low (1-3) with proportional colored bars and percentages. Top emotions ranked list showing the 5 most logged emotions with their icons and frequency counts. Insight cards in a vertical stack with contextual observations like 'Your mood averages 7.4 on days you exercise vs 4.8 without' and 'Weekends score 1.5 points higher than weekdays'. Energy-mood correlation indicator showing whether high energy days correlate with better mood.")
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
