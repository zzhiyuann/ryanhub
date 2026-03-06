import SwiftUI

// MARK: - SpendingTrackerBreakdownView

struct SpendingTrackerBreakdownView: View {
    let viewModel: SpendingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var expandedCategory: SpendingCategory?

    private func categoryColor(for category: SpendingCategory) -> Color {
        switch category {
        case .food: return Color.hubAccentRed
        case .groceries: return Color.hubAccentGreen
        case .transport: return Color.hubPrimary
        case .shopping: return Color.hubAccentYellow
        case .entertainment: return Color(red: 0.56, green: 0.4, blue: 0.95)
        case .health: return Color(red: 0.94, green: 0.35, blue: 0.56)
        case .bills: return Color(red: 0.24, green: 0.7, blue: 0.85)
        case .education: return Color(red: 0.95, green: 0.6, blue: 0.24)
        case .other: return Color(red: 0.6, green: 0.6, blue: 0.65)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {
                monthPicker
                categoryBars
                monthlySummary
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Month Picker

    private var monthPicker: some View {
        HStack {
            Button {
                viewModel.previousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.hubBody.weight(.semibold))
                    .foregroundStyle(Color.hubPrimary)
            }

            Spacer()

            Text(viewModel.selectedMonthDisplayName)
                .font(.hubHeading)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            Button {
                viewModel.nextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.hubBody.weight(.semibold))
                    .foregroundStyle(viewModel.canGoNextMonth ? Color.hubPrimary : AdaptiveColors.textSecondary(for: colorScheme).opacity(0.3))
            }
            .disabled(!viewModel.canGoNextMonth)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Category Bars

    private var categoryBars: some View {
        VStack(spacing: 0) {
            let breakdown = viewModel.categoryBreakdown

            if breakdown.isEmpty {
                HubCard {
                    VStack(spacing: HubLayout.itemSpacing) {
                        Image(systemName: "chart.bar.xaxis")
                            .font(.system(size: 36))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        Text("No spending data this month")
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, HubLayout.sectionSpacing)
                }
            } else {
                let maxAmount = breakdown.first?.total ?? 1

                ForEach(breakdown) { item in
                    VStack(spacing: 0) {
                        categoryRow(item: item, maxAmount: maxAmount)

                        if expandedCategory == item.category {
                            expandedTransactions(for: item.category)
                        }
                    }
                }
            }
        }
    }

    private func categoryRow(item: CategoryBreakdownItem, maxAmount: Double) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) {
                if expandedCategory == item.category {
                    expandedCategory = nil
                } else {
                    expandedCategory = item.category
                }
            }
        } label: {
            HubCard {
                VStack(spacing: 8) {
                    HStack(spacing: HubLayout.itemSpacing) {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 16))
                            .foregroundStyle(categoryColor(for: item.category))
                            .frame(width: 24)

                        Text(item.category.displayName)
                            .font(.hubBody)
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Spacer()

                        Text(String(format: "$%.2f", item.total))
                            .font(.hubBody.weight(.semibold))
                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                        Text(String(format: "%.0f%%", item.percentage))
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .frame(width: 40, alignment: .trailing)

                        Image(systemName: expandedCategory == item.category ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11))
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    GeometryReader { geo in
                        let barWidth = maxAmount > 0 ? (item.total / maxAmount) * geo.size.width : 0
                        RoundedRectangle(cornerRadius: 4)
                            .fill(categoryColor(for: item.category))
                            .frame(width: barWidth, height: 8)
                    }
                    .frame(height: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Expanded Transactions

    private func expandedTransactions(for category: SpendingCategory) -> some View {
        let transactions = filteredTransactions(for: category)

        return VStack(spacing: 0) {
            ForEach(transactions) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if !entry.note.isEmpty {
                            Text(entry.note)
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                        }
                        Text(entry.formattedDate)
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    }

                    Spacer()

                    Text(entry.formattedAmount)
                        .font(.hubBody.weight(.medium))
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .padding(.horizontal, HubLayout.standardPadding + 36)
                .padding(.vertical, 8)

                if entry.id != transactions.last?.id {
                    Divider()
                        .padding(.horizontal, HubLayout.standardPadding + 36)
                }
            }
        }
        .padding(.vertical, 4)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func filteredTransactions(for category: SpendingCategory) -> [SpendingTrackerEntry] {
        let monthEntries = viewModel.entries.filter { entry in
            let range = selectedMonthDayRange
            return entry.dayString >= range.start && entry.dayString < range.end
        }
        return monthEntries
            .filter { $0.category == category }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
    }

    private var selectedMonthDayRange: (start: String, end: String) {
        let calendar = Calendar.current
        let baseDate = calendar.date(byAdding: .month, value: viewModel.selectedMonthOffset, to: Date()) ?? Date()
        let comps = calendar.dateComponents([.year, .month], from: baseDate)
        guard let monthStart = calendar.date(from: comps),
              let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return ("", "")
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return (f.string(from: monthStart), f.string(from: nextMonth))
    }

    // MARK: - Monthly Summary

    private var monthlySummary: some View {
        HubCard {
            HStack(spacing: HubLayout.sectionSpacing) {
                VStack(spacing: 4) {
                    Text("Monthly Total")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Text(String(format: "$%.2f", viewModel.currentMonthTotal))
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))
                    .frame(width: 1, height: 40)

                VStack(spacing: 4) {
                    Text("Daily Average")
                        .font(.hubCaption)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    Text(String(format: "$%.2f", viewModel.selectedMonthAverageDaily))
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 4)
        }
    }
}