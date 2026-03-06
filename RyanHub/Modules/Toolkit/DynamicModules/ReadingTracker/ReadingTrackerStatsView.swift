import SwiftUI

struct ReadingTrackerStatsView: View {
    let viewModel: ReadingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                yearlyGoalSection
                keyMetricsSection
                genreBreakdownSection
                monthlyChartSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Yearly Goal Ring

    private var yearlyGoalSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                ProgressRingView(
                    progress: viewModel.yearlyGoalProgress,
                    current: "\(viewModel.booksFinishedThisYear)",
                    unit: "books",
                    goal: "of \(viewModel.yearlyGoal)",
                    color: Color.hubPrimary,
                    size: 140,
                    lineWidth: 12
                )

                Text(yearlyMotivationalLabel)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)

                if viewModel.booksFinishedThisYear > 0 {
                    Text(viewModel.paceStatus)
                        .font(.hubCaption)
                        .foregroundStyle(paceColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                        .background(paceColor.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.itemSpacing)
        }
    }

    private var yearlyMotivationalLabel: String {
        let remaining = max(viewModel.yearlyGoal - viewModel.booksFinishedThisYear, 0)
        if remaining == 0 {
            return "You've reached your yearly goal!"
        } else if viewModel.booksFinishedThisYear == 0 {
            return "Start reading to work toward your goal"
        } else {
            return "\(remaining) more to reach your \(viewModel.yearlyGoal)-book goal"
        }
    }

    private var paceColor: Color {
        switch viewModel.paceStatus {
        case "On track": return Color.hubAccentGreen
        case "Slightly behind": return Color.hubAccentYellow
        default: return Color.hubAccentRed
        }
    }

    // MARK: - Key Metrics

    private var keyMetricsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Key Metrics")

            StatGrid {
                StatCard(
                    title: "Books Finished",
                    value: "\(viewModel.booksFinishedThisYear)",
                    icon: "checkmark.circle.fill",
                    color: Color.hubAccentGreen
                )
                StatCard(
                    title: "Pages Read",
                    value: formattedPages(viewModel.totalPagesReadThisYear),
                    icon: "doc.text.fill",
                    color: Color.hubPrimary
                )
                StatCard(
                    title: "Avg Rating",
                    value: viewModel.averageRating > 0 ? String(format: "%.1f", viewModel.averageRating) : "—",
                    icon: "star.fill",
                    color: Color.hubAccentYellow
                )
                StatCard(
                    title: "Reading Streak",
                    value: "\(viewModel.readingStreak)d",
                    icon: "flame.fill",
                    color: Color.hubAccentRed
                )
            }
        }
    }

    // MARK: - Genre Breakdown

    private var genreBreakdownSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Genre Breakdown")

            HubCard {
                if viewModel.genreBreakdown.isEmpty {
                    Text("Finish some books to see genre stats")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, HubLayout.sectionSpacing)
                } else {
                    VStack(spacing: 10) {
                        ForEach(viewModel.genreBreakdown.prefix(6), id: \.0) { genre, count in
                            genreBar(genre: genre, count: count)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func genreBar(genre: BookGenre, count: Int) -> some View {
        let total = viewModel.finishedBooks.count
        let fraction = total > 0 ? Double(count) / Double(total) : 0

        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: genre.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(genreColor(for: genre))
                Text(genre.displayName)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
                Text("\(count) (\(Int(fraction * 100))%)")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.15))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(genreColor(for: genre))
                        .frame(width: geometry.size.width * fraction, height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func genreColor(for genre: BookGenre) -> Color {
        let colors: [Color] = [
            Color.hubPrimary,
            Color.hubAccentGreen,
            Color.hubAccentYellow,
            Color.hubAccentRed,
            .orange,
            .cyan,
            .pink,
            .mint,
            .teal,
            .purple,
            .brown
        ]
        let index = (BookGenre.allCases.firstIndex(of: genre) ?? 0) % colors.count
        return colors[index]
    }

    // MARK: - Monthly Chart

    private var monthlyChartSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Monthly Reading Pace")

            ModuleChartView(
                title: "Books Finished",
                subtitle: "\(Calendar.current.component(.year, from: Date()))",
                dataPoints: viewModel.monthlyFinishedChartData,
                style: .bar,
                color: Color.hubPrimary,
                showArea: false
            )
        }
    }

    // MARK: - Helpers

    private func formattedPages(_ pages: Int) -> String {
        if pages >= 1000 {
            return String(format: "%.1fk", Double(pages) / 1000.0)
        }
        return "\(pages)"
    }
}