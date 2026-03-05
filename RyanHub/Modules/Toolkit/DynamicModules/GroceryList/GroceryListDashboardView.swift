import SwiftUI

struct GroceryListDashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    let viewModel: GroceryListViewModel

    private var allEntries: [GroceryListEntry] { viewModel.entries }
    private var purchasedEntries: [GroceryListEntry] { allEntries.filter(\.isPurchased) }
    private var activeEntries: [GroceryListEntry] { allEntries.filter { !$0.isPurchased } }
    private var totalCount: Int { allEntries.count }
    private var purchasedCount: Int { purchasedEntries.count }
    private var completionFraction: Double {
        guard totalCount > 0 else { return 0 }
        return Double(purchasedCount) / Double(totalCount)
    }
    private var estimatedTotal: Double { allEntries.reduce(0) { $0 + $1.lineTotal } }
    private var amountSpent: Double { purchasedEntries.reduce(0) { $0 + $1.lineTotal } }
    private var essentialsPending: [GroceryListEntry] {
        allEntries.filter { $0.priority == .essential && !$0.isPurchased }
    }
    private var recentEntries: [GroceryListEntry] {
        allEntries.sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
    }
    private var budgetFraction: Double {
        guard estimatedTotal > 0 else { return 0 }
        return min(amountSpent / estimatedTotal, 1.0)
    }
    private var tripStatusTitle: String {
        if totalCount == 0 { return "Start Your List" }
        if completionFraction == 1.0 { return "All Done!" }
        if completionFraction == 0.0 { return "Ready to Shop" }
        return "Shopping in Progress"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: HubLayout.sectionSpacing) {
                if totalCount > 0 {
                    shoppingProgressCard
                }
                statsGrid
                if !essentialsPending.isEmpty {
                    essentialAlertsSection
                }
                if !allEntries.isEmpty {
                    recentItemsSection
                } else {
                    emptyState
                }
            }
            .padding(HubLayout.standardPadding)
        }
        .background(AdaptiveColors.background(for: colorScheme))
    }

    // MARK: - Shopping Progress Card

    private var shoppingProgressCard: some View {
        HubCard {
            HStack(alignment: .center, spacing: HubLayout.sectionSpacing) {
                ProgressRingView(
                    progress: completionFraction,
                    current: "\(purchasedCount)",
                    unit: "of \(totalCount)",
                    goal: completionFraction == 1.0 ? "Complete!" : "checked off",
                    color: completionFraction == 1.0 ? Color.hubAccentGreen : Color.hubPrimary,
                    size: 108,
                    lineWidth: 10
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text(tripStatusTitle)
                        .font(.hubHeading)
                        .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))

                    if estimatedTotal > 0 {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.hubAccentYellow)
                                Text("$\(String(format: "%.2f", amountSpent)) / $\(String(format: "%.2f", estimatedTotal))")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(AdaptiveColors.textSecondary(for: colorScheme).opacity(0.2))
                                        .frame(height: 5)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.hubAccentYellow)
                                        .frame(width: geo.size.width * budgetFraction, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }

                    if essentialsPending.isEmpty && totalCount > 0 {
                        Label("All essentials covered", systemImage: "checkmark.circle.fill")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentGreen)
                    } else if !essentialsPending.isEmpty {
                        Label("\(essentialsPending.count) essential\(essentialsPending.count == 1 ? "" : "s") remaining", systemImage: "exclamationmark.circle.fill")
                            .font(.hubCaption)
                            .foregroundStyle(Color.hubAccentRed)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(HubLayout.standardPadding)
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        StatGrid {
            StatCard(
                title: "Total Items",
                value: "\(totalCount)",
                icon: "cart.fill",
                color: Color.hubPrimary
            )
            StatCard(
                title: "Checked Off",
                value: "\(purchasedCount)",
                icon: "checkmark.circle.fill",
                color: Color.hubAccentGreen
            )
            StatCard(
                title: "Est. Budget",
                value: estimatedTotal > 0 ? "$\(String(format: "%.2f", estimatedTotal))" : "—",
                icon: "dollarsign.circle.fill",
                color: Color.hubAccentYellow
            )
            StatCard(
                title: "Essentials Left",
                value: "\(essentialsPending.count)",
                icon: "exclamationmark.circle.fill",
                color: essentialsPending.isEmpty ? Color.hubAccentGreen : Color.hubAccentRed
            )
        }
    }

    // MARK: - Essentials Alert Section

    private var essentialAlertsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Essentials Needed")
            HubCard {
                VStack(spacing: 0) {
                    ForEach(Array(essentialsPending.prefix(4).enumerated()), id: \.element.id) { idx, entry in
                        HStack(spacing: HubLayout.itemSpacing) {
                            ZStack {
                                Circle()
                                    .fill(Color.hubAccentRed.opacity(0.12))
                                    .frame(width: 32, height: 32)
                                Image(systemName: entry.category.icon)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.hubAccentRed)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.itemName)
                                    .font(.hubBody)
                                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                Text("\(entry.quantityWithUnit) · \(entry.category.displayName)")
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                            Spacer()
                            if entry.estimatedPrice > 0 {
                                Text(entry.formattedEstimatedPrice)
                                    .font(.hubCaption)
                                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, HubLayout.standardPadding)

                        if idx < min(essentialsPending.count, 4) - 1 {
                            Divider()
                                .padding(.leading, HubLayout.standardPadding + 32 + HubLayout.itemSpacing)
                        }
                    }

                    if essentialsPending.count > 4 {
                        Text("+ \(essentialsPending.count - 4) more essentials")
                            .font(.hubCaption)
                            .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                            .padding(.horizontal, HubLayout.standardPadding)
                            .padding(.bottom, HubLayout.standardPadding)
                    }
                }
            }
        }
    }

    // MARK: - Recent Items Section

    private var recentItemsSection: some View {
        VStack(alignment: .leading, spacing: HubLayout.itemSpacing) {
            SectionHeader(title: "Recent Items")
            ForEach(recentEntries.prefix(6)) { entry in
                HubCard {
                    HStack(spacing: HubLayout.itemSpacing) {
                        ZStack {
                            Circle()
                                .fill(priorityColor(for: entry.priority).opacity(0.12))
                                .frame(width: 38, height: 38)
                            Image(systemName: entry.category.icon)
                                .font(.system(size: 15))
                                .foregroundStyle(priorityColor(for: entry.priority))
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.summaryLine)
                                .font(.hubBody)
                                .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                                .strikethrough(entry.isPurchased, color: AdaptiveColors.textSecondary(for: colorScheme))
                                .lineLimit(1)
                            Text(entry.formattedDate)
                                .font(.hubCaption)
                                .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                        }

                        Spacer()

                        HStack(spacing: 10) {
                            if entry.isPurchased {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Color.hubAccentGreen)
                            }
                            Button(role: .destructive) {
                                Task { await viewModel.deleteEntry(entry) }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color.hubAccentRed.opacity(0.75))
                            }
                        }
                    }
                    .padding(HubLayout.standardPadding)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        HubCard {
            VStack(spacing: HubLayout.itemSpacing) {
                Image(systemName: "cart.badge.plus")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.hubPrimary.opacity(0.55))
                Text("Your list is empty")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Text("Add items to start planning your grocery trip")
                    .font(.hubBody)
                    .foregroundStyle(AdaptiveColors.textSecondary(for: colorScheme))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(HubLayout.sectionSpacing)
        }
    }

    // MARK: - Helpers

    private func priorityColor(for priority: GroceryPriority) -> Color {
        switch priority {
        case .essential: return Color.hubAccentRed
        case .needed: return Color.hubPrimary
        case .optional: return Color.hubAccentYellow
        }
    }
}