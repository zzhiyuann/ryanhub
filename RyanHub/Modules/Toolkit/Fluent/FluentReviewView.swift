import SwiftUI

// MARK: - Fluent Review View

/// Flashcard review session view with FSRS-based spaced repetition.
/// Displays cards with front/back flip animation and rating buttons.
struct FluentReviewView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: FluentViewModel

    var body: some View {
        if viewModel.reviewCards.isEmpty && !viewModel.isReviewComplete {
            emptyState
        } else if viewModel.isReviewComplete {
            sessionComplete
        } else {
            reviewContent
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HubLayout.sectionSpacing) {
            Spacer()

            ZStack {
                Circle()
                    .fill(AdaptiveColors.surface(for: colorScheme))
                    .frame(width: 96, height: 96)
                    .shadow(color: Color.hubAccentGreen.opacity(0.1), radius: 20, x: 0, y: 8)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(Color.hubAccentGreen)
            }

            VStack(spacing: HubLayout.itemSpacing) {
                Text("All Caught Up!")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text("No cards due for review right now.\nKeep up the great work!")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }

            HubSecondaryButton("Browse Vocabulary", icon: "text.book.closed.fill") {
                viewModel.selectedTab = .vocabulary
            }
            .padding(.horizontal, HubLayout.standardPadding * 3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Session Complete

    private var sessionComplete: some View {
        let accuracy = viewModel.sessionReviewed > 0
            ? (viewModel.sessionCorrect * 100) / viewModel.sessionReviewed
            : 0

        return ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                Spacer(minLength: 40)

                // Result icon
                ZStack {
                    Circle()
                        .fill(AdaptiveColors.surface(for: colorScheme))
                        .frame(width: 96, height: 96)
                        .shadow(color: Color.hubPrimary.opacity(0.1), radius: 20, x: 0, y: 8)

                    Image(systemName: accuracy >= 80 ? "star.fill" : accuracy >= 60 ? "hand.thumbsup.fill" : "flame.fill")
                        .font(.system(size: 40, weight: .light))
                        .foregroundStyle(accuracy >= 80 ? Color.hubAccentYellow : accuracy >= 60 ? Color.hubAccentGreen : Color.hubPrimary)
                }

                Text("Great Session!")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                // Stats
                HStack(spacing: HubLayout.itemSpacing) {
                    sessionStatCard(value: "\(viewModel.sessionReviewed)", label: "Reviewed", color: Color.hubPrimary)
                    sessionStatCard(value: "\(viewModel.sessionCorrect)", label: "Correct", color: Color.hubAccentGreen)
                    sessionStatCard(value: "\(accuracy)%", label: "Accuracy", color: Color.hubAccentYellow)
                }
                .padding(.horizontal, HubLayout.standardPadding)

                // Actions
                VStack(spacing: HubLayout.itemSpacing) {
                    HubButton("Review More", icon: "arrow.clockwise") {
                        viewModel.startReviewSession()
                    }

                    HubSecondaryButton("Back to Home", icon: "house") {
                        viewModel.goToDashboard()
                    }
                }
                .padding(.horizontal, HubLayout.standardPadding * 2)

                Spacer(minLength: 40)
            }
        }
    }

    private func sessionStatCard(value: String, label: String, color: Color) -> some View {
        HubCard {
            VStack(spacing: 4) {
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Review Content

    private var reviewContent: some View {
        VStack(spacing: 0) {
            // Progress header
            progressHeader
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 8)

            // Progress bar
            progressBar
                .padding(.horizontal, HubLayout.standardPadding)
                .padding(.top, 8)

            Spacer()

            // Card
            if let card = viewModel.currentCard {
                flashCard(card)
                    .padding(.horizontal, HubLayout.standardPadding)
            }

            Spacer()

            // Rating buttons (shown when flipped)
            if viewModel.isFlipped {
                ratingButtons
                    .padding(.horizontal, HubLayout.standardPadding)
                    .padding(.bottom, HubLayout.standardPadding)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                // Tap hint
                Text("Tap card to reveal answer")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .padding(.bottom, HubLayout.sectionSpacing)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isFlipped)
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        HStack {
            Text("\(viewModel.todayStats.cardsReviewed) / \(viewModel.settings.dailyGoal)")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            if let card = viewModel.currentCard {
                Text(cardTypeLabel(card.cardType))
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }

    private func cardTypeLabel(_ type: FlashCardType) -> String {
        switch type {
        case .termToDef: return "Term -> Def"
        case .defToTerm: return "Def -> Term"
        case .fillBlank: return "Fill Blank"
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(AdaptiveColors.surfaceSecondary(for: colorScheme))
                    .frame(height: 4)

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.hubPrimary)
                    .frame(width: geometry.size.width * viewModel.reviewProgress, height: 4)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.reviewProgress)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Flash Card

    private func flashCard(_ card: FlashCard) -> some View {
        Button {
            viewModel.flipCard()
        } label: {
            ZStack {
                if !viewModel.isFlipped {
                    // Front
                    cardFace(text: card.front, isFront: true)
                } else {
                    // Back
                    cardFace(text: card.back, isFront: false)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isFlipped)
        }
        .buttonStyle(.plain)
    }

    private func cardFace(text: String, isFront: Bool) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Text(text)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 20)

            if let card = viewModel.currentCard {
                Button {
                    let speakText = isFront ? card.front : card.back.components(separatedBy: "\n").first ?? card.back
                    viewModel.speak(speakText.replacingOccurrences(of: "________", with: "blank"))
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                        .frame(width: 40, height: 40)
                        .background(
                            Circle().fill(Color.hubPrimary.opacity(0.12))
                        )
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 280)
        .background(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .fill(isFront
                    ? AdaptiveColors.surface(for: colorScheme)
                    : Color.hubPrimary.opacity(colorScheme == .dark ? 0.15 : 0.06))
                .shadow(
                    color: colorScheme == .dark
                        ? Color.black.opacity(0.4)
                        : Color.black.opacity(0.08),
                    radius: 12, x: 0, y: 4
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: HubLayout.cardCornerRadius)
                .stroke(
                    isFront ? AdaptiveColors.border(for: colorScheme) : Color.hubPrimary.opacity(0.3),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Rating Buttons

    private var ratingButtons: some View {
        VStack(spacing: 8) {
            Text("How well did you know this?")
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            HStack(spacing: 8) {
                ForEach(FSRSRating.allCases, id: \.rawValue) { rating in
                    ratingButton(rating)
                }
            }
        }
    }

    private func ratingButton(_ rating: FSRSRating) -> some View {
        let color = ratingColor(rating)
        let interval = viewModel.previewIntervals[rating] ?? 0

        return Button {
            viewModel.rateCard(rating)
        } label: {
            VStack(spacing: 4) {
                Text(rating.label)
                    .font(.system(size: 13, weight: .semibold))

                Text(FSRSEngine.formatInterval(interval))
                    .font(.system(size: 10, weight: .medium))
                    .opacity(0.8)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: HubLayout.buttonCornerRadius)
                    .fill(color)
            )
        }
        .disabled(viewModel.isAnimating)
        .opacity(viewModel.isAnimating ? 0.5 : 1)
    }

    private func ratingColor(_ rating: FSRSRating) -> Color {
        switch rating {
        case .again: return .hubAccentRed
        case .hard: return Color.hubAccentYellow
        case .good: return .hubAccentGreen
        case .easy: return .hubPrimary
        }
    }
}
