import SwiftUI

struct ReadingTrackerDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: ReadingTrackerViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing) {
                dailyGoalSection
                statsSection
                streakSection
                if !viewModel.currentlyReading.isEmpty {
                    currentlyReadingSection
                }
                todaySessionsSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Daily Goal

    private var dailyGoalSection: some View {
        HubCard {
            HStack(alignment: .center, spacing: HubLayout.standardPadding) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Today's Reading")
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                    Text(viewModel.isActiveToday ? "You've been reading today 📖" : "Open a book and start your day")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer().frame(height: 4)

                    HStack(spacing: 16) {
                        Label("\(viewModel.todayPagesRead) pages", systemImage: "doc.plaintext")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubPrimary)
                        Label("\(viewModel.todayReadingMinutes) min", systemImage: "clock")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                ProgressRingView(
                    progress: Double(viewModel.todayPagesRead) / Double(max(1, viewModel.dailyPageGoal)),
                    current: "\(viewModel.todayPagesRead)",
                    unit: "pg",
                    goal: "of \(viewModel.dailyPageGoal)",
                    color: Color.hubPrimary,
                    size: 100,
                    lineWidth: 9
                )
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        StatGrid {
            StatCard(
                title: "Pages Today",
                value: "\(viewModel.todayPagesRead)",
                icon: "book.pages",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Books Done",
                value: "\(viewModel.totalBooksCompleted)",
                icon: "checkmark.circle.fill",
                color: Color.hubAccentGreen
            )
            StatCard(
                title: "Min Today",
                value: "\(viewModel.todayReadingMinutes)",
                icon: "clock.fill",
                color: Color.hubAccentYellow
            )
            StatCard(
                title: "Year Goal",
                value: "\(viewModel.booksThisYear)/\(viewModel.yearlyBookGoal)",
                icon: "calendar.badge.checkmark",
                color: Color.hubAccentRed
            )
        }
    }

    // MARK: - Streak

    private var streakSection: some View {
        StreakCounter(
            currentStreak: viewModel.currentStreak,
            longestStreak: viewModel.longestStreak,
            unit: "days",
            isActiveToday: viewModel.isActiveToday
        )
    }

    // MARK: - Currently Reading

    private var currentlyReadingSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Currently Reading")
            ForEach(viewModel.currentlyReading) { book in
                HubCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.hubPrimary.opacity(0.14))
                                    .frame(width: 44, height: 44)
                                Image(systemName: book.genre.icon)
                                    .font(.system(size: 20))
                                    .foregroundStyle(Color.hubPrimary)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.hubBody)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    .lineLimit(1)
                                Text(book.author)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                CompactProgressRing(
                                    progress: book.progressPercent,
                                    color: Color.hubPrimary,
                                    size: 38
                                )
                                Text("\(Int(book.progressPercent * 100))%")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }

                        VStack(alignment: .leading, spacing: 5) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.hubPrimary.opacity(0.13))
                                        .frame(height: 6)
                                    Capsule()
                                        .fill(
                                            LinearGradient(
                                                colors: [Color.hubPrimary, Color(hex: "#818CF8")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * max(0, min(1, book.progressPercent)), height: 6)
                                }
                            }
                            .frame(height: 6)

                            HStack {
                                Text("Page \(book.currentPage) of \(book.totalPages)")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                Spacer()
                                Text("\(book.pagesRemaining) pages left")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                    }
                    .padding(HubLayout.standardPadding)
                }
            }
        }
    }

    // MARK: - Today's Sessions

    private var todaySessionsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Today's Sessions")

            if viewModel.todayEntries.isEmpty {
                HubCard {
                    VStack(spacing: 10) {
                        Image(systemName: "book.closed.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.5))
                        Text("No sessions logged today")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("Log a reading session to track your progress.")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HubLayout.sectionSpacing)
                    .padding(.horizontal, HubLayout.standardPadding)
                }
            } else {
                ForEach(viewModel.todayEntries) { entry in
                    sessionRow(entry)
                }
            }
        }
    }

    private func sessionRow(_ entry: ReadingTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor(entry.status).opacity(0.13))
                        .frame(width: 44, height: 44)
                    Image(systemName: entry.status.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(statusColor(entry.status))
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.summaryLine)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        if !entry.progressDisplay.isEmpty {
                            Text("·")
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            Text(entry.progressDisplay)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    if entry.hasRating {
                        Text(entry.ratingDisplay)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Color.hubAccentYellow)
                    }

                    Button {
                        Task { await viewModel.deleteEntry(entry) }
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.hubAccentRed.opacity(0.65))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(HubLayout.standardPadding)
        }
    }

    private func statusColor(_ status: ReadingStatus) -> Color {
        switch status {
        case .reading: return Color.hubPrimary
        case .completed: return Color.hubAccentGreen
        case .paused: return Color.hubAccentYellow
        case .wantToRead: return Color(hex: "#818CF8")
        case .abandoned: return Color.hubAccentRed
        }
    }
}