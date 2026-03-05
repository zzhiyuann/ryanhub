import SwiftUI

struct GroceryListAnalyticsView: View {
    let viewModel: GroceryListViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            LazyVStack(spacing: HubLayout.sectionSpacing) {
                summaryStatsSection
                spendingTrendSection
                categoryBreakdownSection
                frequentItemsSection
                shoppingTripsSection
                insightsSection
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Summary Stats

    private var summaryStatsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Shopping Overview")

            StatGrid {
                StatCard(
                    title: "Total Trips",
                    value: "\(viewModel.totalTrips)",
                    icon: "cart.fill",
                    color: Color.hubPrimary
                )
                StatCard(
                    title: "Items Purchased",
                    value: "\(viewModel.totalItemsBought)",
                    icon: "checkmark.circle.fill",
                    color: Color.hubAccentGreen
                )
                StatCard(
                    title: "Total Spent",
                    value: viewModel.formattedTotalSpent,
                    icon: "dollarsign.circle.fill",
                    color: Color.hubAccentYellow
                )
                StatCard(
                    title: "Avg Basket",
                    value: viewModel.formattedAverageBasket,
                    icon: "bag.fill",
                    color: Color.hubAccentRed
                )
            }
        }
    }

    // MARK: - Spending Trend

    private var spendingTrendSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Spending Trend")

            ModuleChartView(
                title: "Weekly Spend",
                subtitle: "Last 8 weeks",
                dataPoints: viewModel.weeklySpendData,
                style: .bar,
                color: Color.hubPrimary,
                showArea: true
            )
        }
    }

    // MARK: - Category Breakdown

    private var categoryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Spending by Category")

            HubCard {
                if viewModel.categorySpending.isEmpty {
                    Text("No category data yet")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HubLayout.standardPadding)
                } else {
                    VStack(spacing: HubLayout.itemSpacing) {
                        ForEach(viewModel.categorySpending.prefix(6)) { spend in
                            CategorySpendRow(spend: spend, colorScheme: colorScheme)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Frequent Items

    private var frequentItemsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Frequently Bought")

            HubCard {
                if viewModel.frequentItems.isEmpty {
                    Text("No frequent items yet")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HubLayout.standardPadding)
                } else {
                    VStack(spacing: HubLayout.itemSpacing) {
                        ForEach(Array(viewModel.frequentItems.prefix(5).enumerated()), id: \.element.id) { index, item in
                            FrequentItemRow(item: item, rank: index + 1, colorScheme: colorScheme)
                            if index < min(viewModel.frequentItems.count, 5) - 1 {
                                Divider()
                                    .background(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Recent Shopping Trips

    private var shoppingTripsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Recent Trips")

            if viewModel.shoppingTrips.isEmpty {
                HubCard {
                    Text("No trips recorded yet")
                        .font(.hubBody)
                        .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, HubLayout.standardPadding)
                }
            } else {
                VStack(spacing: HubLayout.itemSpacing) {
                    ForEach(viewModel.shoppingTrips.prefix(4)) { trip in
                        ShoppingTripCard(trip: trip, colorScheme: colorScheme)
                    }
                }
            }
        }
    }

    // MARK: - Insights

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Insights")
            InsightsList(insights: viewModel.insights)
        }
    }
}

// MARK: - Category Spend Row

private struct CategorySpendRow: View {
    let spend: GroceryCategorySpend
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Image(systemName: spend.category.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.hubPrimary)
                    .frame(width: 20)

                Text(spend.category.displayName)
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Spacer()

                Text(spend.formattedTotal)
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                Text(spend.formattedPercentage)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .frame(width: 36, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.15))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.hubPrimary)
                        .frame(width: geo.size.width * (spend.percentage / 100), height: 6)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Frequent Item Row

private struct FrequentItemRow: View {
    let item: GroceryFrequentItem
    let rank: Int
    let colorScheme: ColorScheme

    private var rankColor: Color {
        switch rank {
        case 1: return Color.hubAccentYellow
        case 2: return AdaptiveColors.textSecondary(for: colorScheme)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return Color.hubPrimary.opacity(0.5)
        }
    }

    var body: some View {
        HStack(spacing: HubLayout.itemSpacing) {
            Text("\(rank)")
                .font(.hubCaption)
                .fontWeight(.bold)
                .foregroundStyle(rankColor)
                .frame(width: 20, alignment: .center)

            Image(systemName: item.lastCategory.icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.hubPrimary)
                .frame(width: 24)

            Text(item.itemName)
                .font(.hubBody)
                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.count)x")
                    .font(.hubBody)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.hubPrimary)
                Text(item.lastCategory.displayName)
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
            }
        }
    }
}

// MARK: - Shopping Trip Card

private struct ShoppingTripCard: View {
    let trip: GroceryShoppingTrip
    let colorScheme: ColorScheme

    var completionColor: Color {
        if trip.completionRate >= 90 { return Color.hubAccentGreen }
        if trip.completionRate >= 60 { return Color.hubAccentYellow }
        return Color.hubAccentRed
    }

    var body: some View {
        HubCard {
            HStack(spacing: HubLayout.itemSpacing) {
                CompactProgressRing(
                    progress: trip.completionRate / 100,
                    color: completionColor,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(trip.formattedDate)
                        .font(.hubBody)
                        .fontWeight(.semibold)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    HStack(spacing: 8) {
                        Label("\(trip.totalItems) items", systemImage: "list.bullet")
                        Label("\(trip.purchasedCount) bought", systemImage: "checkmark")
                    }
                    .font(.hubCaption)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(trip.formattedTotalSpend)
                        .font(.hubBody)
                        .fontWeight(.bold)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if trip.allEssentialsPurchased {
                        Label("All essentials", systemImage: "checkmark.seal.fill")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentGreen)
                    } else {
                        Text("\(String(format: "%.0f", trip.completionRate))% done")
                            .font(.hubCaption)
                            .foregroundStyle(completionColor)
                    }
                }
            }
        }
    }
}