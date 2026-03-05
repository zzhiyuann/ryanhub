import SwiftUI

// MARK: - Streak Counter

/// Displays current and best streak with a flame animation.
/// Motivational gamification element for daily tracking modules.
struct StreakCounter: View {
    @Environment(\.colorScheme) private var colorScheme

    let currentStreak: Int
    let longestStreak: Int
    let unit: String
    let isActiveToday: Bool

    init(
        currentStreak: Int,
        longestStreak: Int,
        unit: String = "days",
        isActiveToday: Bool = false
    ) {
        self.currentStreak = currentStreak
        self.longestStreak = longestStreak
        self.unit = unit
        self.isActiveToday = isActiveToday
    }

    var body: some View {
        HubCard {
            HStack(spacing: 16) {
                // Flame icon
                ZStack {
                    Circle()
                        .fill(flameColor.opacity(0.12))
                        .frame(width: 52, height: 52)

                    Image(systemName: currentStreak > 0 ? "flame.fill" : "flame")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(flameColor)
                        .symbolEffect(.bounce, value: isActiveToday)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(currentStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text(unit)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text("Current Streak")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                // Best streak
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.hubAccentYellow)
                        Text("\(longestStreak)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    }

                    Text("Best")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
        }
    }

    private var flameColor: Color {
        if currentStreak >= 30 { return Color.hubAccentRed }
        if currentStreak >= 7 { return Color(red: 1.0, green: 0.5, blue: 0.0) } // Orange
        if currentStreak > 0 { return Color.hubAccentYellow }
        return AdaptiveColors.textSecondary(for: colorScheme)
    }
}
