import SwiftUI

@MainActor
struct CatCareTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: CatCareTrackerViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                healthStatusBanner
                statGridSection
                feedingProgressSection
                streakSection
                todayEntriesSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Health Status Banner

    private var healthStatusBanner: some View {
        HubCard {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Text("🐱")
                        .font(.system(size: 34))
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Today's Care")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text(Date().formatted(date: .long, time: .omitted))
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    if viewModel.hasUnresolvedSymptomToday {
                        Label("Symptom Logged", systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.hubAccentRed)
                    } else {
                        Label("All Good", systemImage: "checkmark.seal.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.hubAccentGreen)
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    ZStack {
                        Circle()
                            .fill(viewModel.hasUnresolvedSymptomToday
                                  ? Color.hubAccentRed.opacity(0.15)
                                  : Color.hubAccentGreen.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: viewModel.hasUnresolvedSymptomToday
                              ? "exclamationmark.triangle.fill"
                              : "heart.fill")
                            .foregroundStyle(viewModel.hasUnresolvedSymptomToday
                                             ? Color.hubAccentRed
                                             : Color.hubAccentGreen)
                            .font(.title3)
                    }
                    Text(viewModel.hasUnresolvedSymptomToday ? "Alert" : "Healthy")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Stat Grid

    private var statGridSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Key Metrics")
            StatGrid {
                StatCard(
                    title: "Fed Today",
                    value: "\(viewModel.todayFeedingCount)×",
                    icon: "fork.knife",
                    color: Color.hubPrimary
                )
                StatCard(
                    title: "Latest Weight",
                    value: viewModel.latestWeightFormatted,
                    icon: "scalemass.fill",
                    color: Color.hubAccentYellow
                )
                StatCard(
                    title: "Days Since Vet",
                    value: viewModel.daysSinceLastVetVisitText,
                    icon: "cross.case.fill",
                    color: Color.hubAccentGreen
                )
                StatCard(
                    title: "Symptoms (7d)",
                    value: "\(viewModel.recentSymptomCount)",
                    icon: "exclamationmark.triangle.fill",
                    color: viewModel.recentSymptomCount > 0 ? Color.hubAccentRed : Color.hubAccentGreen
                )
            }
        }
    }

    // MARK: - Feeding Progress

    private var feedingProgressSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Feeding Goal")
                            .font(.hubHeading)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        Text("Meals logged today")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                        Spacer().frame(height: 4)

                        feedTypePills
                    }

                    Spacer()

                    ProgressRingView(
                        progress: viewModel.feedingProgress,
                        current: "\(viewModel.todayFeedingCount)",
                        unit: "meals",
                        goal: "of \(viewModel.dailyFeedingGoal)",
                        color: Color.hubPrimary,
                        size: 96,
                        lineWidth: 9
                    )
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private var feedTypePills: some View {
        let activeFeedTypes = FeedType.allCases.filter { viewModel.todayCountForFeedType($0) > 0 }
        return Group {
            if activeFeedTypes.isEmpty {
                Text("No feedings yet")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.6))
            } else {
                HStack(spacing: 6) {
                    ForEach(activeFeedTypes) { feedType in
                        HStack(spacing: 4) {
                            Image(systemName: feedType.icon)
                                .font(.system(size: 10))
                            Text("\(viewModel.todayCountForFeedType(feedType))")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.hubPrimary.opacity(0.12))
                        .foregroundStyle(Color.hubPrimary)
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Care Streak")
            StreakCounter(
                currentStreak: viewModel.currentStreak,
                longestStreak: viewModel.longestStreak,
                unit: "days",
                isActiveToday: viewModel.hasEntryToday
            )
        }
    }

    // MARK: - Today's Entries

    private var todayEntriesSection: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Events")

            if viewModel.todayEntries.isEmpty {
                HubCard {
                    VStack(spacing: 14) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.hubPrimary.opacity(0.35))
                        Text("No events logged today")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Tap + to record a feeding, vet visit, or more")
                            .font(.hubCaption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.65))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                }
            } else {
                VStack(spacing: HubLayout.itemSpacing) {
                    ForEach(viewModel.todayEntries) { entry in
                        entryRow(entry)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func entryRow(_ entry: CatCareTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11)
                        .fill(eventColor(for: entry.eventType).opacity(0.14))
                        .frame(width: 44, height: 44)
                    Image(systemName: entry.eventType.icon)
                        .foregroundStyle(eventColor(for: entry.eventType))
                        .font(.body)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(entry.eventType.displayName.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(eventColor(for: entry.eventType))
                        Spacer()
                        Text(entry.parsedDate.formatted(date: .omitted, time: .shortened))
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .fontWeight(.medium)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if !entry.detailLine.isEmpty {
                        Text(entry.detailLine)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    }

                    if entry.catMood != .calm {
                        HStack(spacing: 4) {
                            Image(systemName: entry.catMood.icon)
                                .font(.system(size: 10))
                            Text(entry.catMood.displayName)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            entry.catMood.isPositive
                                ? Color.hubAccentGreen.opacity(0.13)
                                : Color.hubAccentRed.opacity(0.13)
                        )
                        .foregroundStyle(
                            entry.catMood.isPositive ? Color.hubAccentGreen : Color.hubAccentRed
                        )
                        .clipShape(Capsule())
                    }
                }

                Button {
                    Task { await viewModel.deleteEntry(entry) }
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(Color.hubAccentRed.opacity(0.65))
                        .font(.body)
                        .padding(8)
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Helpers

    private func eventColor(for type: EventType) -> Color {
        switch type {
        case .feeding:     return Color.hubPrimary
        case .vetVisit:    return Color.hubAccentGreen
        case .weightCheck: return Color.hubAccentYellow
        case .medication:  return Color(red: 0.58, green: 0.40, blue: 0.92)
        case .symptom:     return Color.hubAccentRed
        }
    }
}