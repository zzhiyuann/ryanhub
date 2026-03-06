import SwiftUI

struct ReadingTrackerNowReadingView: View {
    let viewModel: ReadingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                // MARK: - Daily Progress Header
                dailyProgressHeader

                // MARK: - Currently Reading Books
                if viewModel.filteredCurrentlyReading.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Currently Reading")
                        ForEach(viewModel.filteredCurrentlyReading) { entry in
                            bookCard(for: entry)
                        }
                    }
                }
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Daily Progress Header

    private var dailyProgressHeader: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                HStack(spacing: HubLayout.standardPadding) {
                    // Reading streak badge
                    streakBadge

                    Spacer()

                    // Daily page goal ring
                    ProgressRingView(
                        progress: viewModel.dailyGoalProgress,
                        current: "\(viewModel.todayPagesRead)",
                        unit: "pages",
                        goal: "of \(viewModel.dailyGoal)",
                        color: Color.hubPrimary,
                        size: 80,
                        lineWidth: 8
                    )
                }
            }
        }
    }

    private var streakBadge: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: viewModel.readingStreak > 0 ? "flame.fill" : "flame")
                    .font(.system(size: 22))
                    .foregroundStyle(viewModel.readingStreak > 0 ? Color.hubAccentYellow : AdaptiveColors.textSecondary(for: colorScheme))

                Text("\(viewModel.readingStreak)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            Text("day streak")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            if viewModel.longestStreak > 0 {
                Text("Best: \(viewModel.longestStreak) days")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    // MARK: - Book Card

    private func bookCard(for entry: ReadingTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.standardPadding) {
                // Cover color placeholder
                coverPlaceholder(for: entry)

                // Book info
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.hubBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        .lineLimit(2)

                    Text(entry.author)
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    // Page progress text
                    Text("\(entry.currentPage)/\(entry.totalPages) pages")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    // Linear progress bar
                    progressBar(for: entry)

                    // Quick-update stepper
                    pageStepper(for: entry)
                }

                Spacer(minLength: 0)

                // Percentage ring
                VStack {
                    ProgressRingView(
                        progress: entry.progressFraction,
                        current: entry.progressPercentFormatted,
                        color: genreColor(for: entry.genre),
                        size: 56,
                        lineWidth: 5
                    )

                    Text(entry.formattedLastRead)
                        .font(.system(size: 11))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Cover Placeholder

    private func coverPlaceholder(for entry: ReadingTrackerEntry) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(genreColor(for: entry.genre).gradient)
                .frame(width: 52, height: 72)

            VStack(spacing: 2) {
                Image(systemName: entry.genre.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.white.opacity(0.9))

                Text(entry.genre.displayName)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Progress Bar

    private func progressBar(for entry: ReadingTrackerEntry) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))

                RoundedRectangle(cornerRadius: 3)
                    .fill(genreColor(for: entry.genre))
                    .frame(width: geo.size.width * entry.progressFraction)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Page Stepper

    private func pageStepper(for entry: ReadingTrackerEntry) -> some View {
        HStack(spacing: 8) {
            Button {
                let newPage = max(entry.currentPage - 10, 0)
                Task { await viewModel.updateCurrentPage(for: entry, to: newPage) }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(entry.currentPage > 0 ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
            }
            .disabled(entry.currentPage <= 0)

            Text("+10 pg")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Button {
                let newPage = min(entry.currentPage + 10, entry.totalPages)
                Task { await viewModel.updateCurrentPage(for: entry, to: newPage) }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(entry.currentPage < entry.totalPages ? Color.hubAccentGreen : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.4))
            }
            .disabled(entry.currentPage >= entry.totalPages)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HubLayout.standardPadding) {
            Spacer(minLength: 40)

            Image(systemName: "book.closed.fill")
                .font(.system(size: 56))
                .foregroundStyle(Color.hubPrimary.opacity(0.4))

            Text("No Books in Progress")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Start reading a book from your library\nor add a new one to get going.")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .multilineTextAlignment(.center)

            if !viewModel.wantToReadBooks.isEmpty {
                VStack(spacing: 8) {
                    Text("From your reading list:")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    ForEach(viewModel.wantToReadBooks.prefix(3)) { book in
                        HubCard {
                            HStack {
                                Image(systemName: book.genre.icon)
                                    .foregroundStyle(genreColor(for: book.genre))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(book.title)
                                        .font(.hubBody)
                                        .fontWeight(.medium)
                                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        .lineLimit(1)

                                    Text(book.author)
                                        .font(.hubCaption)
                                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                }

                                Spacer()

                                Button {
                                    Task { await viewModel.changeStatus(for: book, to: .reading) }
                                } label: {
                                    Text("Start")
                                        .font(.hubCaption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.hubPrimary, in: Capsule())
                                }
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }

            Spacer(minLength: 40)
        }
        .padding(.horizontal, HubLayout.standardPadding)
    }

    // MARK: - Helpers

    private func genreColor(for genre: BookGenre) -> Color {
        switch genre {
        case .fiction: return Color.hubPrimary
        case .nonFiction: return Color.hubAccentGreen
        case .scienceFiction: return .cyan
        case .fantasy: return .purple
        case .mystery: return Color.hubAccentYellow
        case .biography: return .orange
        case .selfHelp: return .mint
        case .history: return .brown
        case .science: return .teal
        case .philosophy: return .indigo
        case .other: return AdaptiveColors.textSecondary(for: colorScheme)
        }
    }
}