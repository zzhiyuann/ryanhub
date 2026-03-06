import SwiftUI

struct MoodJournalTodayView: View {
    let viewModel: MoodJournalViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                moodFaceSection
                streakSection
                if viewModel.hasCheckedInToday {
                    todayEntriesSection
                } else {
                    motivationalPrompt
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Mood Face

    private var moodFaceSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                ZStack {
                    Circle()
                        .fill(moodColor.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: moodFaceIcon)
                        .font(.system(size: 48))
                        .foregroundStyle(moodColor)
                        .symbolRenderingMode(.hierarchical)
                }

                if viewModel.hasCheckedInToday, let latest = viewModel.latestEntry {
                    Text(latest.emotion.displayName)
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("Mood: \(viewModel.latestMoodRating)/10 · \(latest.energyDescription)")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                } else {
                    Text("How are you feeling?")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    Text("No check-in yet today")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.itemSpacing)
        }
    }

    private var moodFaceIcon: String {
        guard viewModel.hasCheckedInToday else { return "face.dashed" }
        let rating = viewModel.latestMoodRating
        switch rating {
        case 1...2: return "face.smiling.inverse"
        case 3...4: return "face.dashed"
        case 5...6: return "face.dashed"
        case 7...8: return "face.smiling"
        case 9...10: return "face.smiling.fill"
        default: return "face.dashed"
        }
    }

    private var moodColor: Color {
        guard viewModel.hasCheckedInToday else { return Color.hubPrimary }
        let rating = viewModel.latestMoodRating
        switch rating {
        case 1...3: return Color.hubAccentRed
        case 4...6: return Color.hubAccentYellow
        case 7...10: return Color.hubAccentGreen
        default: return Color.hubPrimary
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        StreakCounter(
            currentStreak: viewModel.currentStreak,
            longestStreak: viewModel.longestStreak,
            unit: "days",
            isActiveToday: viewModel.hasCheckedInToday
        )
    }

    // MARK: - Motivational Prompt

    private var motivationalPrompt: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: "sun.and.horizon")
                    .font(.system(size: 36))
                    .foregroundStyle(Color.hubAccentYellow)

                Text("Take a moment to check in")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("Tracking your mood daily helps you understand patterns and build self-awareness. Tap + to log how you're feeling right now.")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)

                if viewModel.currentStreak > 0 {
                    Text("Don't break your \(viewModel.currentStreak)-day streak!")
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubAccentYellow)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.itemSpacing)
        }
    }

    // MARK: - Today Entries

    private var todayEntriesSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Check-Ins")

            ForEach(viewModel.todayEntries) { entry in
                moodEntryCard(entry)
            }
        }
    }

    private func moodEntryCard(_ entry: MoodJournalEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(entryColor(for: entry.rating))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: entry.emotion.icon)
                            .foregroundStyle(entryColor(for: entry.rating))

                        Text(entry.emotion.displayName)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Spacer()

                        Text(entry.timeString)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    HStack(spacing: HubLayout.itemSpacing) {
                        Label("\(entry.rating)/10", systemImage: entry.moodFace)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Label(entry.energyDescription, systemImage: "bolt.fill")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    if entry.hasNotes {
                        Text(entry.notes)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(2)
                            .padding(.top, 2)
                    }
                }
            }
        }
    }

    private func entryColor(for rating: Int) -> Color {
        switch rating {
        case 1...3: return Color.hubAccentRed
        case 4...6: return Color.hubAccentYellow
        case 7...10: return Color.hubAccentGreen
        default: return Color.hubPrimary
        }
    }
}