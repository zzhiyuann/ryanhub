import SwiftUI

struct SpendingTrackerView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var viewModel = SpendingTrackerViewModel()
    @State private var selectedTab = 0
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.hubPrimary.opacity(0.12))
                        .frame(width: 40, height: 40)
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Color.hubPrimary)
                }
                Text("Spending Tracker")
                    .font(.hubHeading)
                    .foregroundStyle(AdaptiveColors.textPrimary(for: colorScheme))
                Spacer()
            }
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, 8)

            // Tab picker
            Picker("", selection: $selectedTab) {
                    Text("Today").tag(0)
                    Text("Breakdown").tag(1)
                    Text("Trends").tag(2)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, HubLayout.standardPadding)
            .padding(.bottom, HubLayout.itemSpacing)

            // Content
            ZStack(alignment: .bottomTrailing) {
                    if selectedTab == 0 {
                        SpendingTrackerTodayView(viewModel: viewModel)
                    }
                    if selectedTab == 1 {
                        SpendingTrackerBreakdownView(viewModel: viewModel)
                    }
                    if selectedTab == 2 {
                        SpendingTrackerTrendsView(viewModel: viewModel)
                    }

                // FAB
                QuickEntryFAB {
                    showAddSheet = true
                }
                .padding(HubLayout.standardPadding)
            }
        }
        .background(AdaptiveColors.background(for: colorScheme))
        .task { await viewModel.loadData() }
        .sheet(isPresented: $showAddSheet) {
            SpendingTrackerExpenseEntrySheet(viewModel: viewModel) {
                showAddSheet = false
            }
        }
    }
}
