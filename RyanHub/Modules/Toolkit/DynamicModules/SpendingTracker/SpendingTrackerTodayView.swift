import SwiftUI

struct SpendingTrackerTodayView: View {
    let viewModel: SpendingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    private var ringColor: Color {
        let progress = viewModel.dailyBudgetProgress
        if progress >= 0.9 {
            return Color.hubAccentRed
        } else if progress >= 0.6 {
            return Color.hubAccentYellow
        } else {
            return Color.hubAccentGreen
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                budgetRingSection
                todaySummarySection
                expenseListSection
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.vertical, HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Budget Ring

    private var budgetRingSection: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                ProgressRingView(
                    progress: viewModel.dailyBudgetProgress,
                    current: String(format: "$%.0f", viewModel.dailyBudgetRemaining),
                    unit: "left",
                    goal: "of $\(String(format: "%.0f", viewModel.dailyBudget))",
                    color: ringColor,
                    size: 160,
                    lineWidth: 14
                )

                if viewModel.isOverBudget {
                    Text("Over budget!")
                        .font(.hubCaption)
                        .foregroundStyle(Color.hubAccentRed)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HubLayout.itemSpacing)
        }
    }

    // MARK: - Today Summary

    private var todaySummarySection: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Spent Today")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text(String(format: "$%.2f", viewModel.todayTotal))
                    .font(.hubTitle)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("Remaining")
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text(String(format: "$%.2f", viewModel.dailyBudgetRemaining))
                    .font(.hubTitle)
                    .foregroundStyle(viewModel.isOverBudget ? Color.hubAccentRed : Color.hubAccentGreen)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Expense List

    @ViewBuilder
    private var expenseListSection: some View {
        if viewModel.todayEntries.isEmpty {
            emptyStateView
        } else {
            VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                SectionHeader(title: "Today's Expenses")

                ForEach(viewModel.todayEntries) { entry in
                    expenseRow(entry)
                }
            }
        }
    }

    private func expenseRow(_ entry: SpendingTrackerEntry) -> some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: entry.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 36, height: 36)
                    .background(Color.hubPrimary.opacity(0.12))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.category.displayName)
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if !entry.note.isEmpty {
                        Text(entry.note)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .lineLimit(1)
                    } else {
                        Text(entry.timeString)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                }

                Spacer()

                Text(entry.formattedAmount)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: HubLayout.itemSpacing) {
            Spacer()
                .frame(height: 24)

            Image(systemName: "creditcard")
                .font(.system(size: 48))
                .foregroundStyle(Color.hubPrimary.opacity(0.4))

            Text("No expenses yet today")
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Text("Tap + to log your first expense")
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))

            Spacer()
                .frame(height: 24)
        }
        .frame(maxWidth: .infinity)
    }
}