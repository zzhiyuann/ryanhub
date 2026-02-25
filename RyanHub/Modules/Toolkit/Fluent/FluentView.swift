import SwiftUI

// MARK: - Fluent View

/// Native Fluent language learning module.
/// Replaces the previous WebView wrapper with a fully native SwiftUI implementation.
/// Features: vocabulary browsing, FSRS-based flashcard review, TTS pronunciation,
/// daily goal tracking, and word of the day.
struct FluentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = FluentViewModel()

    var body: some View {
        VStack(spacing: 0) {
            // Content area
            switch viewModel.selectedTab {
            case .dashboard:
                dashboardContent
            case .vocabulary:
                FluentVocabularyView(viewModel: viewModel)
            case .review:
                FluentReviewView(viewModel: viewModel)
            }

            // Bottom tab bar
            bottomTabBar
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .sheet(isPresented: $viewModel.showSettings) {
            FluentSettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showVocabularyDetail) {
            if let item = viewModel.selectedVocabItem {
                FluentVocabularyDetailView(item: item, viewModel: viewModel)
            }
        }
        .onAppear {
            viewModel.loadData()
        }
    }

    // MARK: - Bottom Tab Bar

    private var bottomTabBar: some View {
        HStack(spacing: 0) {
            tabButton(.dashboard, icon: "house.fill", label: "Home")
            tabButton(.vocabulary, icon: "text.book.closed.fill", label: "Vocab")
            tabButton(.review, icon: "rectangle.stack.fill", label: "Review")

            // Settings button (separate from tabs)
            Button {
                viewModel.showSettings = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 20, weight: .medium))
                    Text("Settings")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(
            AdaptiveColors.surface(for: colorScheme)
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.3)
                        : Color.black.opacity(0.06),
                    radius: 8, x: 0, y: -2
                )
        )
    }

    private func tabButton(_ tab: FluentTab, icon: String, label: String) -> some View {
        let isSelected = viewModel.selectedTab == tab
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                viewModel.selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme))
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                // Daily goal ring (with streak badge)
                dailyGoalCard
                    .padding(.top, 8)

                // Word of the day
                if let word = viewModel.wordOfTheDay {
                    wordOfTheDayCard(word)
                }

                // Stats row
                statsRow

                // Quick actions
                quickActions
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.sectionSpacing)
        }
    }

    // MARK: - Daily Goal Card

    private var dailyGoalCard: some View {
        HubCard {
            HStack(spacing: HubLayout.standardPadding) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(
                            AdaptiveColors.surfaceSecondary(for: colorScheme),
                            lineWidth: 8
                        )
                        .frame(width: 72, height: 72)

                    Circle()
                        .trim(from: 0, to: goalProgress)
                        .stroke(
                            Color.hubPrimary,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round)
                        )
                        .frame(width: 72, height: 72)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: goalProgress)

                    VStack(spacing: 0) {
                        Text("\(viewModel.todayStats.cardsReviewed)")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.hubPrimary)
                        Text("/\(viewModel.settings.dailyGoal)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Daily Goal")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Spacer()

                        // Streak badge (compact, top-right of card)
                        if viewModel.progress.currentStreak > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.hubAccentRed)
                                Text("\(viewModel.progress.currentStreak)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                            )
                        }
                    }

                    Text("\(viewModel.dueCardCount) cards due for review")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

                    if viewModel.dueCardCount > 0 {
                        Button {
                            viewModel.selectedTab = .review
                        } label: {
                            Text("Start Review")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(Color.hubPrimary)
                                )
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var goalProgress: Double {
        guard viewModel.settings.dailyGoal > 0 else { return 0 }
        return min(1.0, Double(viewModel.todayStats.cardsReviewed) / Double(viewModel.settings.dailyGoal))
    }

    // MARK: - Word of the Day

    private func wordOfTheDayCard(_ word: VocabularyItem) -> some View {
        HubCard {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                HStack {
                    SectionHeader(title: "Word of the Day")
                    Spacer()
                    Button {
                        viewModel.speak(word.term)
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.hubPrimary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle().fill(Color.hubPrimary.opacity(0.12))
                            )
                    }
                }

                Text(word.term)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(word.definition)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineSpacing(2)

                if let chinese = word.chineseDefinition, viewModel.settings.showChinese {
                    Text(chinese)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.hubPrimary.opacity(0.8))
                }

                if let example = word.examples.first {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "text.quote")
                            .font(.system(size: 12))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .padding(.top, 2)

                        Text(example)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .italic()
                            .lineSpacing(2)
                    }
                }

                // Category badge
                HStack {
                    Spacer()
                    Text(word.category.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.hubPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.hubPrimary.opacity(0.12))
                        )
                }
            }
        }
        .onTapGesture {
            viewModel.showDetail(for: word)
        }
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            statCard(
                value: "\(viewModel.progress.totalCardsReviewed)",
                label: "Total Reviews",
                icon: "rectangle.stack.fill",
                color: Color.hubPrimary
            )
            statCard(
                value: viewModel.progress.totalCardsReviewed > 0
                    ? "\(viewModel.progress.totalCorrect * 100 / viewModel.progress.totalCardsReviewed)%"
                    : "—",
                label: "Accuracy",
                icon: "checkmark.circle.fill",
                color: Color.hubAccentGreen
            )
            statCard(
                value: "\(viewModel.progress.longestStreak)",
                label: "Best Streak",
                icon: "flame.fill",
                color: Color.hubAccentRed
            )
        }
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        HubCard {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)

                Text(value)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Quick Actions")

            HStack(spacing: HubLayout.itemSpacing) {
                quickActionButton(
                    title: "Browse Words",
                    icon: "text.book.closed.fill",
                    color: Color.hubPrimaryLight
                ) {
                    viewModel.selectedTab = .vocabulary
                }

                quickActionButton(
                    title: "Review Cards",
                    icon: "rectangle.stack.fill",
                    color: Color.hubAccentGreen
                ) {
                    viewModel.selectedTab = .review
                }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(color.opacity(0.12))
                    )

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .padding(HubLayout.cardInnerPadding)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .shadow(
                        color: colorScheme == .dark
                            ? Color.black.opacity(0.3)
                            : Color.black.opacity(0.06),
                        radius: 8, x: 0, y: 2
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    FluentView()
}
