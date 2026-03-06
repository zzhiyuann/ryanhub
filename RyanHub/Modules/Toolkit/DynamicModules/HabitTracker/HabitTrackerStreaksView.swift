import SwiftUI

struct HabitTrackerStreaksView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: HabitTrackerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                HubCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Visual streak showcase. Top section is a GitHub-style 12-week contribution heatmap calendar — each cell represents one day, colored from gray (0%) through light green to dark green (100% habits completed). Tapping a day shows a popover listing which habits were completed. Below the heatmap, a vertically scrolling list of per-habit streak cards sorted by current streak descending. Each card shows: habit icon, name, current streak with flame emoji and day count, best-ever streak with trophy icon, and a 7-day trailing dot strip (filled green dot = completed, hollow gray dot = missed). Cards for habits with streaks above 7 days get a subtle golden border glow.")
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
