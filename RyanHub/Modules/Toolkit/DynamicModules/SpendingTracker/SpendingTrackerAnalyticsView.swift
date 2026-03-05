import SwiftUI

struct SpendingTrackerAnalyticsView: View {
    let viewModel: SpendingTrackerViewModel
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Computed Analytics

    private var allEntries: [SpendingTrackerEntry] {
        viewModel.entries
    }

    private var totalSpend: Double {
        allEntries.reduce(0) { $0 + $1.amount }
    }

    private var thisMonthEntries: [SpendingTrackerEntry] {
        let cal = Calendar.current
        let now = Date()
        return allEntries.filter {
            cal.isDate($0.parsedDate, equalTo: now, toGranularity: .month)
        }
    }

    private var thisMonthSpend: Double {
        thisMonthEntries.reduce(0) { $0 + $1.amount }
    }

    private var avgDailySpend: Double {
        let cal = Calendar.current
        let days = Set(allEntries.map { cal.startOfDay(for: $0.parsedDate) })
        guard !days.isEmpty else { return 0 }
        return totalSpend / Double(days.count)
    }

    private var largestSingleTransaction: SpendingTrackerEntry? {
        allEntries.max(by: { $0.amount < $1.amount })
    }

    private var recurringTotal: Double {
        allEntries.filter { $0.isRecurring }.reduce(0) { $0 + $1.amount }
    }

    private var topCategory: SpendingCategory? {
        let grouped = Dictionary(grouping: allEntries, by: { $0.category })
        return grouped.max(by: { a, b in
            a.value.reduce(0) { $0 + $1.amount } < b.value.reduce(0) { $0 + $1.amount }
        })?.key
    }

    private var categoryBreakdown: [(category: SpendingCategory, total: Double)] {
        let grouped = Dictionary(grouping: allEntries, by: { $0.category })
        return SpendingCategory.allCases.compactMap { cat in
            let total = grouped[cat]?.reduce(0) { $0 + $1.amount } ?? 0
            return total > 0 ? (cat, total) : nil
        }.sorted { $0.total > $1.total }
    }

    private var weeklyChartData: [ChartDataPoint] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<7).reversed().map { offset -> ChartDataPoint in
            let day = cal.date(byAdding: .day, value: -offset, to: today) ?? today
            let dayEntries = allEntries.filter { cal.isDate($0.parsedDate, inSameDayAs: day) }
            let total = dayEntries.reduce(0) { $0 + $1.amount }
            let formatter = DateFormatter()
            formatter.dateFormat = "E"
            return ChartDataPoint(label: formatter.string(from: day), value: total)
        }
    }

    private var mostUsedPayment: PaymentMethod? {
        let grouped = Dictionary(grouping: allEntries, by: { $0.paymentMethod })
        return grouped.max(by: { $0.value.count < $1.value.count })?.key
    }

    private var insights: [ModuleInsight] {
        var result: [ModuleInsight] = []

        if let top = topCategory {
            let topTotal = categoryBreakdown.first?.total ?? 0
            let pct = totalSpend > 0 ? Int(topTotal / totalSpend * 100) : 0
            result.append(ModuleInsight(
                type: .trend,
                title: "Top Category: \(top.displayName)",
                message: "\(pct)% of your spending goes to \(top.displayName.lowercased()). That's \(String(format: "$%.2f", topTotal)) overall."
            ))
        }

        if recurringTotal > 0 {
            result.append(ModuleInsight(
                type: .warning,
                title: "Recurring Costs",
                message: String(format: "$%.2f in recurring expenses logged. Review subscriptions and fixed costs regularly.", recurringTotal)
            ))
        }

        if avgDailySpend > 0 {
            result.append(ModuleInsight(
                type: .suggestion,
                title: "Daily Average",
                message: String(format: "You spend an average of $%.2f per day. Projecting $%.2f this month.", avgDailySpend, avgDailySpend * 30)
            ))
        }

        if let largest = largestSingleTransaction {
            result.append(ModuleInsight(
                type: .achievement,
                title: "Largest Transaction",
                message: "\(largest.formattedAmount) on \(largest.category.displayName)\(largest.note.isEmpty ? "" : ": \(largest.note)")."
            ))
        }

        return result
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: HubLayout.sectionSpacing) {

                // Weekly Chart
                ModuleChartView(
                    title: "7-Day Spending",
                    subtitle: "Daily totals this week",
                    dataPoints: weeklyChartData,
                    style: .bar,
                    color: Color.hubPrimary,
                    showArea: false
                )

                // Summary Stats
                StatGrid {
                    StatCard(
                        title: "This Month",
                        value: String(format: "$%.2f", thisMonthSpend),
                        icon: "calendar",
                        color: Color.hubPrimary
                    )
                    StatCard(
                        title: "Daily Average",
                        value: String(format: "$%.2f", avgDailySpend),
                        icon: "chart.line.uptrend.xyaxis",
                        color: Color.hubAccentYellow
                    )
                    StatCard(
                        title: "All-Time Total",
                        value: String(format: "$%.2f", totalSpend),
                        icon: "dollarsign.circle.fill",
                        color: Color.hubAccentGreen
                    )
                    StatCard(
                        title: "Transactions",
                        value: "\(allEntries.count)",
                        icon: "list.bullet.rectangle.fill",
                        color: Color.hubAccentRed
                    )
                }

                // Category Breakdown
                if !categoryBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "By Category")
                        HubCard {
                            VStack(spacing: 0) {
                                ForEach(Array(categoryBreakdown.enumerated()), id: \.element.category.id) { index, item in
                                    if index > 0 {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                    CategoryBreakdownRow(
                                        category: item.category,
                                        total: item.total,
                                        percentage: totalSpend > 0 ? item.total / totalSpend : 0,
                                        colorScheme: colorScheme
                                    )
                                }
                            }
                        }
                    }
                }

                // Payment Methods
                let paymentBreakdown = computePaymentBreakdown()
                if !paymentBreakdown.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Payment Methods")
                        HubCard {
                            VStack(spacing: HubLayout.itemSpacing) {
                                ForEach(paymentBreakdown, id: \.method.id) { item in
                                    HStack(spacing: 12) {
                                        Image(systemName: item.method.icon)
                                            .font(.system(size: 16))
                                            .foregroundStyle(Color.hubPrimary)
                                            .frame(width: 28)
                                        Text(item.method.displayName)
                                            .font(.hubBody)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                        Spacer()
                                        Text("\(item.count) txn\(item.count == 1 ? "" : "s")")
                                            .font(.hubCaption)
                                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                                        Text(String(format: "$%.2f", item.total))
                                            .font(.hubBody)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                    }
                                }
                            }
                            .padding(HubLayout.standardPadding)
                        }
                    }
                }

                // Recurring vs One-time
                if recurringTotal > 0 || totalSpend > 0 {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Spending Type")
                        HubCard {
                            HStack(spacing: HubLayout.standardPadding) {
                                SpendingTypeGauge(
                                    label: "Recurring",
                                    amount: recurringTotal,
                                    total: totalSpend,
                                    color: Color.hubAccentRed,
                                    colorScheme: colorScheme
                                )
                                Divider().frame(height: 60)
                                SpendingTypeGauge(
                                    label: "One-Time",
                                    amount: totalSpend - recurringTotal,
                                    total: totalSpend,
                                    color: Color.hubAccentGreen,
                                    colorScheme: colorScheme
                                )
                            }
                            .padding(HubLayout.standardPadding)
                        }
                    }
                }

                // Insights
                if !insights.isEmpty {
                    VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
                        SectionHeader(title: "Insights")
                        InsightsList(insights: insights)
                    }
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Helpers

    private func computePaymentBreakdown() -> [(method: PaymentMethod, total: Double, count: Int)] {
        let grouped = Dictionary(grouping: allEntries, by: { $0.paymentMethod })
        return PaymentMethod.allCases.compactMap { method in
            let items = grouped[method] ?? []
            guard !items.isEmpty else { return nil }
            let total = items.reduce(0) { $0 + $1.amount }
            return (method, total, items.count)
        }.sorted { $0.total > $1.total }
    }
}

// MARK: - Category Breakdown Row

private struct CategoryBreakdownRow: View {
    let category: SpendingCategory
    let total: Double
    let percentage: Double
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Image(systemName: category.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 28)
                Text(category.displayName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
                Text(String(format: "%.0f%%", percentage * 100))
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                Text(String(format: "$%.2f", total))
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.hubPrimary)
                        .frame(width: geo.size.width * percentage, height: 4)
                }
            }
            .frame(height: 4)
            .padding(.leading, 40)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, HubLayout.standardPadding)
    }
}

// MARK: - Spending Type Gauge

private struct SpendingTypeGauge: View {
    let label: String
    let amount: Double
    let total: Double
    let color: Color
    let colorScheme: ColorScheme

    private var percentage: Double {
        total > 0 ? amount / total : 0
    }

    var body: some View {
        VStack(spacing: 6) {
            ProgressRingView(
                progress: percentage,
                current: String(format: "$%.0f", amount),
                color: color,
                size: 72,
                lineWidth: 7
            )
            Text(label)
                .font(.hubCaption)
                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            Text(String(format: "%.0f%%", percentage * 100))
                .font(.hubCaption)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
    }
}