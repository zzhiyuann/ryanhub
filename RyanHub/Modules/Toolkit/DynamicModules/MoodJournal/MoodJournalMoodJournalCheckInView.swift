import SwiftUI

struct MoodJournalMoodJournalCheckInView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: MoodJournalViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Primary check-in screen. Shows a large animated emoji face that morphs based on the mood slider value (frown at 1, flat at 5, beaming at 10) with a background color gradient that shifts from deep red through amber to vibrant green. Below the face: a custom gradient slider (red→yellow→green) for 1-10 mood rating with haptic feedback on value changes. Then a horizontal scrollable row of emotion tag chips (pill-shaped buttons with SF Symbol + label, highlighted with hubPrimaryLight when selected). Energy level displayed as a 5-dot battery-style indicator where users tap dots to fill. Quick-tap activity bubbles in a flowing layout (exercise, work, social, family, sleep, nature, reading, music, cooking, travel) that toggle selection with a gentle scale animation. Collapsible text area for optional freeform notes. Large 'Save Check-In' button at bottom using HubButton style. If already checked in today, shows the existing entry in a review card with an 'Update' option instead of fresh entry.")
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
